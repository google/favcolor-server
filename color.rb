# -*- coding: utf-8 -*-
# Copyright 2012-14 Google Inc.
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

module Chooser

  class Color
    def self.random
      r = Random.new
      s = ''
      3.times do
        s += format("%02x", r.rand(256))
      end
      s
    end

    def self.favorite(account)
      locals = {}
      name = account['displayName']
      name ||= account['email']
      locals[:display_name] = name

      color = account['color']
      greeting = ''
      if (color)
        greeting = "We know your favorite color!"
      else
        greeting = "We don’t know your favorite color, so " +
          "we’re picking one at random."
        color = Color.random
      end
      locals[:favorite_color] = color
      r = color[0..1]; g = color[2..3]; b = color[4..5]
      locals[:rgb] = "0x#{r}, 0x#{g}, 0x#{b}"

      greeting += " Since we’re geeks, we give colors geeky names. " +
        "Here’s yours:"
      locals[:greeting] = greeting
      
      if account['photoUrl'] 
        photo = account['photoUrl']
      else
        photo = ''
      end
      locals[:photo_url] = photo
      locals
    end
  end

end
