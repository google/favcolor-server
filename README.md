# FavColor server

A demo app for a variety of identity technologies, including OAuth 2, OpenID COnnect, and Persona.

## favcolor.net

Integrates with the Google, Microsoft, Facebook, and Mozilla Persona IDPs.  
Mostly OAuth 2.0-based, except for Facebook is subtly incompatible and Persona
is something completely different.

## favcolor.net/gat

Integrates with the Google “Identity Toolkit” software, which takes care of all the user management stuff, including passwords, recovery, and federation with lots of IDPs.

## components

This is the server side of the code, a Ruby/Sinatra thing which uses filesystem storage with some help from memcached.

Also, there’s an Android client at https://github.com/google/favcolor-android and an iOS client at https://github.com/google/favcolor-android

