# Copyright 2012 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#  
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# Tim, why can't you just use one of the excellent Ruby templating packages?!

module Chooser
  class Page
    PAYLOAD = "_PAYLOAD_"
    NARRATIVE = "_NARRATIVE_"
    PHOTO = '_PHOTO_'
    
    HEAD = "<head>" +
      "SCRIPT\n" +
      '<script type="text/javascript" src="jscolor/jscolor.js"></script>' +
      "<link rel='stylesheet' type='text/css' href='/chooser.css' />\n" +
      "<title>Chooser: TITLE</title>\n" +
      "<link href=\"bootstrap/css/bootstrap.min.css\" rel=\"stylesheet\">\n" +
      "</head>"
    BODY = "<body>" +
      "<div class=\"row-fluid\" id=\"container\">\n" +
      "<div class=\"span3\" id=\"left\">\n" +
      "<img src=\"g60s.png\" /><br/>" +
      "<img src=\"r96s.png\" /><br/>" +
      "<img src=\"b88s.png\" />\n" +
      "</div>\n" +
      "<div class=\"span8\">\n" +
      "<div class=\"row\">\<div class=\"span12\">\n" +
      "<h2>H2 _PHOTO_</h2></div></div>\n" +
      "<script src=\"//code.jquery.com/jquery-latest.js\"></script>\n" +
      "<script src=\"js/bootstrap.min.js\"></script>\n" +
      NARRATIVE +
      PAYLOAD +
      "</div></div></body>"

    def initialize(title, script = '')
      @header = HEAD.sub('TITLE', title).sub('SCRIPT', script)
      @body = BODY.dup
    end

    def h2!(title)
      @body.gsub!('H2', title)
    end

    def narrative!(text)
      @body.gsub!(NARRATIVE, text + "\n")
    end

    def photo!(url)
      @body.gsub!(PHOTO, "<img src=\"#{url}\" />")
    end
    
    def payload!(text)
      @body.gsub!(PAYLOAD, text + "\n")
    end

    def to_s
      t = @body.gsub(NARRATIVE, '').gsub(PAYLOAD, '').gsub(PHOTO, '')
      "<!DOCTYPE html>\n<html>\n#{@header}\n#{t}\n</html>"
    end

    def self.parse_hash_script
      "function getHashParams() {

    var hashParams = {};
    var e,
        a = /\+/g,  // Regex for replacing addition symbol with a space
        r = /([^&;=]+)=?([^&;]*)/g,
        d = function (s) { return decodeURIComponent(s.replace(a, \" \")); },
        q = window.location.hash.substring(1);

    while (e = r.exec(q))
       hashParams[d(e[1])] = d(e[2]);

    return hashParams;
}\n"
    end
  end
end
