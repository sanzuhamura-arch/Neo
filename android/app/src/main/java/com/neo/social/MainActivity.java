package com.neo.social;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Color;
import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.TextView;

public class MainActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER);
        root.setBackgroundColor(Color.rgb(11, 11, 15));

        TextView title = new TextView(this);
        title.setText("NEO");
        title.setTextColor(Color.WHITE);
        title.setTextSize(38);
        title.setGravity(Gravity.CENTER);

        TextView subtitle = new TextView(this);
        subtitle.setText("Social");
        subtitle.setTextColor(Color.rgb(167, 139, 250));
        subtitle.setTextSize(20);
        subtitle.setGravity(Gravity.CENTER);

        root.addView(title);
        root.addView(subtitle);

        setContentView(root);
    }
          }
