/*
 * Copyright 2012 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.textuality.favcolor;

import java.util.Random;

import yuku.ambilwarna.AmbilWarnaDialog;
import android.accounts.AccountManager;
import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.AsyncTask;
import android.os.Bundle;
import android.util.Log;
import android.view.Menu;
import android.view.View;
import android.widget.TextView;

import com.google.android.gms.auth.GoogleAuthUtil;
import com.google.android.gms.auth.UserRecoverableAuthException;
import com.google.android.gms.common.AccountPicker;

public class FavColorMain extends Activity implements DataReceiver {

    public static final String TAG = "FavColor";

    private static final int PICKER_REQUEST_CODE = 485794312;
    private static final int AUTHUTIL_REQUEST_CODE = 84123594;
    private static final String SERVER_CLIENT_ID = "424861364121.apps.googleusercontent.com";
    private static final String SCOPE = "audience:server:client_id:" + SERVER_CLIENT_ID;
    
    private static final String PREF = "FavColor";
    private static final String PREF_NAME = "displayName";
    private static final String PREF_COLOR = "color";
    
    private SharedPreferences mPrefs;
    private String mEmail = null;
    private Random mRand;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // still buggy after all these years
        System.setProperty("http.keepAlive", "false");

        mRand = new Random();
        mPrefs = getSharedPreferences(PREF, 0);
        
        TextView t = (TextView) findViewById(R.id.message);
        t.setOnClickListener(new View.OnClickListener() {
            
            @Override
            public void onClick(View view) {
                if (mEmail == null) {
                    return;
                }
                AmbilWarnaDialog dialog = new AmbilWarnaDialog(FavColorMain.this, 0, new AmbilWarnaDialog.OnAmbilWarnaListener() {
                    
                    @Override
                    public void onOk(AmbilWarnaDialog dialog, int color) {
                        saveColorPref(color);
                        showFavorite();
                        new GetToken(new Updater(color)).execute();
                    }
                    
                    @Override
                    public void onCancel(AmbilWarnaDialog dialog) {
                    }
                });
                dialog.show();
            }
        });
        
        t = (TextView) findViewById(R.id.switcher);
        t.setOnClickListener(new View.OnClickListener() {
            
            @Override
            public void onClick(View view) {
                pickAndGo();                
            }
        });
        
        pickAndGo();
    }
    
    private void pickAndGo() {
        Intent intent = AccountPicker.newChooseAccountIntent(null, null, new String[]{"com.google"}, 
                false, null, null, null, null);  
        startActivityForResult(intent, PICKER_REQUEST_CODE);        
    }
    
    private void showFavorite() {
        
        String message = getString(R.string.hello);
        int color = mPrefs.getInt("color", -1);
        String name = mPrefs.getString(PREF_NAME, null);
        if (name != null) {
            message += " " + name + "! ";
        } else {
            message += "! ";
        }
        if (color != -1) {
            message += getString(R.string.your_color);
        } else {
            message += getString(R.string.unknown_color);
            int r = mRand.nextInt(256), g = mRand.nextInt(256), b = mRand.nextInt(256);
            color = (0xff << 24) | (r << 16) | (g << 8) | b;
        }
        View background = findViewById(R.id.container);
        background.setBackgroundColor(color);
        TextView readout = (TextView) findViewById(R.id.message);
        readout.setText(message);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == PICKER_REQUEST_CODE && resultCode == RESULT_OK) {
 
            mEmail = data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME);
            new GetToken(new Fetcher(this)).execute();
            
        } else if (requestCode == AUTHUTIL_REQUEST_CODE && resultCode == RESULT_OK) {
            new GetToken(new Fetcher(this)).execute();
        }
    }

    class GetToken extends AsyncTask<Void, Void, String> {
        
        private final AsyncTask<String, Void, Void> mCustomer;

        public GetToken(AsyncTask<String, Void, Void> customer) {
            mCustomer = customer;
        }
        
        @Override
        protected String doInBackground(Void... params) {
            String token = null;
            try {
                // if this works, token is guaranteed to be usable
                token = GoogleAuthUtil.getToken(FavColorMain.this, mEmail, SCOPE);

            } catch (UserRecoverableAuthException userAuthEx) {
                startActivityForResult(userAuthEx.getIntent(), AUTHUTIL_REQUEST_CODE);
                token = null;

            }  catch (Exception e) {
                Log.d(TAG, "OOPS! " + e.getClass().toString() + "/" + e.getLocalizedMessage());
                throw new RuntimeException(e);
            }
            return token;
        }

        @Override
        protected void onPostExecute(String token) {
            super.onPostExecute(token);
            if (token != null) {
                mCustomer.execute(token);
            }
        }
    }

    private void saveColorPref(int color) {
        SharedPreferences.Editor editor = mPrefs.edit();
        editor.putInt(PREF_COLOR, color);
        editor.commit();
    }
    
    public void receive(Account account) {
        SharedPreferences.Editor editor = mPrefs.edit();
        if (account.displayName() != null) {
            editor.putString(PREF_NAME, account.displayName());
        } 
        saveColorPref(account.color());
        editor.commit();
        
        showFavorite();
    }
    public void notFound() {
        TextView t = (TextView) findViewById(R.id.message);
        t.setText(getString(R.string.not_found));
        View background = findViewById(R.id.container);
        background.setBackgroundColor(0xffbbbbbb);
        mEmail = null;
     }
  
    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.activity_main, menu);
        return true;
    }
}
