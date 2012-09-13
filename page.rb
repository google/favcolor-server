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
    
    HEAD = "<head>" +
      "SCRIPT\n" +
      '<script type="text/javascript" src="jscolor/jscolor.js"></script>' +
      "<link rel='stylesheet' type='text/css' href='/chooser.css' />\n" +
      "<link href='http://fonts.googleapis.com/css?family=Droid+Sans:400,700' rel='stylesheet' type='text/css'>\n" +
      "<title>Chooser: TITLE</title>\n" +
      "</head>"
    BODY = "<body>" +
      "<h2>H2</h2>\n" +
      NARRATIVE +
      PAYLOAD +
      "</div></body>"

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
    
    def payload!(text)
      @body.gsub!(PAYLOAD, text + "\n")
    end

    def to_s
      t = @body.gsub(NARRATIVE, '').gsub(PAYLOAD, '')
      "<html>\n#{@header}\n#{t}\n</html>"
    end

  end
end
