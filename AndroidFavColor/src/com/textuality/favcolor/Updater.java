package com.textuality.favcolor;

import java.io.IOException;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLEncoder;

import android.os.AsyncTask;
import android.util.Log;

public class Updater extends AsyncTask<String, Void, Void> {

    private final URL mFavColorSet;
    private String mProblem = null;
    
    private final int mColor;

    public Updater(int color) {
        mColor = color & 0x00ffffff;
        try {
            mFavColorSet = new URL("https://favcolor.net/set-color");
        } catch (MalformedURLException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    protected Void doInBackground(String... params) {
        String token = params[0];
        String payload = "id_token=" + URLEncoder.encode(token) + "&color=" + URLEncoder.encode(Integer.toHexString(mColor).toUpperCase()); 
        byte[] data = payload.getBytes();
        HttpURLConnection conn = null;

        OutputStream out;
        int http_status;
        try {
            conn = (HttpURLConnection) mFavColorSet.openConnection();
            conn.setDoOutput(true);
            conn.setFixedLengthStreamingMode(data.length);
            conn.addRequestProperty("Content-type", "application/x-www-form-urlencoded");
            // this opens a connection, then sends POST & headers.
            out = conn.getOutputStream(); 
            out.write(data);

            http_status = conn.getResponseCode();
            if (http_status / 100 != 2) {
                mProblem = "HTTP failure, status=" + http_status + ", " + conn.getResponseMessage();
            }
        } catch (IOException e) {
            mProblem = e.getLocalizedMessage();
        } finally {
            conn.disconnect(); // Let's practice good hygiene
        }

        return null;
    }

    @Override
    protected void onPostExecute(Void result) {
        if (mProblem != null) {
            Log.d(FavColorMain.TAG, "Color update failed: " + mProblem);
        }
    }
}
