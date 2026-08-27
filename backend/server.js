const express = require("express");
const cors = require("cors");
const jwt = require("jsonwebtoken");
const { Pool } = require("pg");

const app = express();

app.use(cors());
app.use(express.json({ limit: "20mb" }));

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL
    ? { rejectUnauthorized: false }
    : false
});

const JWT_SECRET =
  process.env.JWT_SECRET || "CHANGE_THIS_SECRET";

function createToken(user) {
  return jwt.sign(
    {
      id: user.id,
      username: user.username,
      role: user.role
    },
    JWT_SECRET,
    { expiresIn: "7d" }
  );
}

function auth(req, res, next) {
  const header = req.headers.authorization || "";

  if (!header.startsWith("Bearer ")) {
    return res.status(401).json({
      error: "Unauthorized"
    });
  }

  try {
    req.user = jwt.verify(
      header.slice(7),
      JWT_SECRET
    );

    next();
  } catch {
    return res.status(401).json({
      error: "Invalid token"
    });
  }
}

function developerOnly(req, res, next) {
  if (req.user.role !== "developer") {
    return res.status(403).json({
      error: "Developer access required"
    });
  }

  if (
    process.env.DEVELOPER_USER_ID &&
    String(req.user.id) !==
      String(process.env.DEVELOPER_USER_ID)
  ) {
    return res.status(403).json({
      error: "Developer access denied"
    });
  }

  next();
}

/* HEALTH */

app.get("/api/health", (req, res) => {
  res.json({
    ok: true,
    app: "NEO Social",
    version: "1.0.0"
  });
});

/* REGISTER */

app.post("/api/auth/register", async (req, res) => {
  try {
    const {
      email,
      username,
      password
    } = req.body;

    if (!email || !username || !password) {
      return res.status(400).json({
        error: "Email, username and password are required"
      });
    }

    const result = await pool.query(
      `
      INSERT INTO users
      (email, username, password_hash)
      VALUES ($1, $2, $3)
      RETURNING id, email, username, role, neo_tier
      `,
      [email, username, password]
    );

    const user = result.rows[0];

    res.json({
      user,
      token: createToken(user)
    });

  } catch (error) {
    console.error(error);

    res.status(400).json({
      error: "Email or username already exists"
    });
  }
});

/* LOGIN */

app.post("/api/auth/login", async (req, res) => {
  try {
    const {
      email,
      password
    } = req.body;

    const result = await pool.query(
      `
      SELECT *
      FROM users
      WHERE email = $1
      AND password_hash = $2
      `,
      [email, password]
    );

    if (!result.rows.length) {
      return res.status(401).json({
        error: "Invalid login"
      });
    }

    const user = result.rows[0];

    if (
      user.banned_until &&
      new Date(user.banned_until) > new Date()
    ) {
      return res.status(403).json({
        error: "Account is currently banned",
        banned_until: user.banned_until
      });
    }

    res.json({
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        role: user.role,
        neo_tier: user.neo_tier
      },
      token: createToken(user)
    });

  } catch (error) {
    console.error(error);

    res.status(500).json({
      error: "Server error"
    });
  }
});

/* FEED */

app.get("/api/feed", auth, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        p.*,
        u.username,
        u.neo_tier
      FROM posts p
      JOIN users u
        ON u.id = p.user_id
      WHERE p.deleted_at IS NULL
      ORDER BY p.created_at DESC
      LIMIT 100
    `);

    res.json(result.rows);

  } catch (error) {
    console.error(error);

    res.status(500).json({
      error: "Could not load feed"
    });
  }
});

/* CREATE POST */

app.post("/api/posts", auth, async (req, res) => {
  try {
    const {
      body,
      media_url
    } = req.body;

    if (!body && !media_url) {
      return res.status(400).json({
        error: "Post cannot be empty"
      });
    }

    const result = await pool.query(
      `
      INSERT INTO posts
      (user_id, body, media_url)
      VALUES ($1, $2, $3)
      RETURNING *
      `,
      [
        req.user.id,
        body || "",
        media_url || null
      ]
    );

    await pool.query(
      `
      INSERT INTO activity_logs
      (actor_id, action, target_type, target_id)
      VALUES ($1, $2, $3, $4)
      `,
      [
        req.user.id,
        "create_post",
        "post",
        result.rows[0].id
      ]
    );

    res.json(result.rows[0]);

  } catch (error) {
    console.error(error);

    res.status(500).json({
      error: "Could not create post"
    });
  }
});

/* REACTION */

app.post(
  "/api/posts/:id/reactions",
  auth,
  async (req, res) => {

    const type = req.body.type || "like";

    await pool.query(
      `
      INSERT INTO reactions
      (user_id, post_id, type)
      VALUES ($1, $2, $3)

      ON CONFLICT (user_id, post_id)
      DO UPDATE SET type = EXCLUDED.type
      `,
      [
        req.user.id,
        req.params.id,
        type
      ]
    );

    res.json({
      ok: true,
      reaction: type
    });
  }
);

/* DEVELOPER BAN */

app.post(
  "/api/admin/users/:id/ban",
  auth,
  developerOnly,
  async (req, res) => {

    const hours = Number(
      req.body.hours || 0
    );

    const bannedUntil =
      hours > 0
        ? new Date(
            Date.now() +
            hours * 60 * 60 * 1000
          )
        : null;

    await pool.query(
      `
      UPDATE users
      SET banned_until = $1
      WHERE id = $2
      `,
      [
        bannedUntil,
        req.params.id
      ]
    );

    await pool.query(
      `
      INSERT INTO activity_logs
      (actor_id, action, target_type, target_id, metadata)
      VALUES ($1, $2, $3, $4, $5)
      `,
      [
        req.user.id,
        "ban_user",
        "user",
        req.params.id,
        JSON.stringify({ hours })
      ]
    );

    res.json({
      ok: true,
      banned_until: bannedUntil
    });
  }
);

/* DEVELOPER MUTE */

app.post(
  "/api/admin/users/:id/mute",
  auth,
  developerOnly,
  async (req, res) => {

    const hours = Number(
      req.body.hours || 24
    );

    const mutedUntil =
      new Date(
        Date.now() +
        hours * 60 * 60 * 1000
      );

    await pool.query(
      `
      UPDATE users
      SET muted_until = $1
      WHERE id = $2
      `,
      [
        mutedUntil,
        req.params.id
      ]
    );

    res.json({
      ok: true,
      muted_until: mutedUntil
    });
  }
);

/* GIVE NEO */

app.post(
  "/api/admin/users/:id/neo",
  auth,
  developerOnly,
  async (req, res) => {

    const tier = Math.max(
      0,
      Math.min(
        3,
        Number(req.body.tier || 0)
      )
    );

    await pool.query(
      `
      UPDATE users
      SET neo_tier = $1
      WHERE id = $2
      `,
      [
        tier,
        req.params.id
      ]
    );

    await pool.query(
      `
      INSERT INTO activity_logs
      (actor_id, action, target_type, target_id, metadata)
      VALUES ($1, $2, $3, $4, $5)
      `,
      [
        req.user.id,
        "set_neo",
        "user",
        req.params.id,
        JSON.stringify({ tier })
      ]
    );

    res.json({
      ok: true,
      neo_tier: tier
    });
  }
);

/* DELETE ANY POST */

app.delete(
  "/api/admin/posts/:id",
  auth,
  developerOnly,
  async (req, res) => {

    await pool.query(
      `
      UPDATE posts
      SET deleted_at = NOW()
      WHERE id = $1
      `,
      [req.params.id]
    );

    res.json({
      ok: true
    });
  }
);

/* ACTIVITY LOG */

app.get(
  "/api/admin/activity",
  auth,
  developerOnly,
  async (req, res) => {

    const result = await pool.query(`
      SELECT
        a.*,
        u.username
      FROM activity_logs a
      LEFT JOIN users u
        ON u.id = a.actor_id
      ORDER BY a.created_at DESC
      LIMIT 500
    `);

    res.json(result.rows);
  }
);

const PORT =
  process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(
    `NEO Social API running on port ${PORT}`
  );
});
