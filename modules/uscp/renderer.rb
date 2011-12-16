# {"id"=>"urn:activity:1534", "actor"=>{"id"=>"urn:member:3851611", "title"=>"Doris Tong", "image"=>"/p/3/000/053/2e2/2d83926.jpg", "type"=>"urn:linkedin:member"}, "verb"=>{"type"=>"urn:linkedin:share", "commentary"=>"Learn about AdWords conversion funnels!"}, "object"=>{"com.linkedin.ucp.common.ActivityObject"=>{"title"=>"Adwords Conversion Funnels & Attribution Models: Can They Work Together?", "url"=>"http://searchengineland.com/adwords-conversion-funnels-attribution-models-can-they-work-together-89314", "description"=>"First click. Last click. Linear. Reverse decay. Linear reverse decay\342\200\246everyone accepts that attribution is a necessary consideration in analytics, but no one seems to be able to crack the code. There are countless ways to attribute revenue, yet the major analytics systems stick with the traditional last entry. The reality is that we, they, you, [...]", "image"=>"http://searchengineland.com/figz/wp-content/seloads/2011/08/time-lag-300x153.png"}}, "destination"=>"urn:member:3851611", "visibility"=>"PUBLIC", "createdDate"=>1323201844003, "app"=>{"com.linkedin.ucp.common.ActivityObject"=>{"id"=>"urn:app:linkedin", "title"=>"LinkedIn", "description"=>"professional network thingy"}}, "body"=>"Doris Tong shared Adwords Conversion Funnels & Attribution Models: Can They Work Together?", "bodyAnnotations"=>[{"entity"=>{"id"=>"urn:member:3851611", "title"=>"Doris Tong", "image"=>"/p/3/000/053/2e2/2d83926.jpg", "type"=>"urn:linkedin:member"}, "range"=>{"start"=>0, "end"=>10}}, {"entity"=>{"title"=>"Adwords Conversion Funnels & Attribution Models: Can They Work Together?", "url"=>"http://searchengineland.com/adwords-conversion-funnels-attribution-models-can-they-work-together-89314", "description"=>"First click. Last click. Linear. Reverse decay. Linear reverse decay\342\200\232\303\204\302\266everyone accepts that attribution is a necessary consideration in analytics, but no one seems to be able to crack the code. There are countless ways to attribute revenue, yet the major analytics systems stick with the traditional last entry. The reality is that we, they, you, [...]", "image"=>"http://searchengineland.com/figz/wp-content/seloads/2011/08/time-lag-300x153.png"}, "range"=>{"start"=>18, "end"=>90}}], "socialSummary"=>{"totalComments"=>0, "recentComments"=>[], "totalLikes"=>0, "recentLikes"=>[], "likedByCurrentUser"=>false, "totalShares"=>0, "verbSummaries"=>{"urn:linkedin:like"=>{"total"=>0, "recent"=>[], "actedOnByCurrentUser"=>false}}}}

# {"id"=>"urn:activity:1527", "actor"=>{"id"=>"urn:member:3851611", "title"=>"Doris Tong", "image"=>"/p/3/000/053/2e2/2d83926.jpg", "type"=>"urn:linkedin:member"}, "verb"=>{"type"=>"urn:linkedin:recommend-by", "commentary"=>"In Doris, I not only found a great recruiter and a representative of LinkedIn's culture, but also an...", "attributes"=>{"recommendationId"=>"12345"}}, "object"=>{"com.linkedin.ucp.common.ActivityObject"=>{"id"=>"urn:member:20031783", "title"=>"Nipun Dave", "image"=>"/p/2/000/0db/139/012129e.jpg", "type"=>"urn:linkedin:member"}}, "destination"=>"urn:member:3851611", "visibility"=>"PUBLIC", "createdDate"=>1323200476406, "app"=>{"com.linkedin.ucp.common.ActivityObject"=>{"id"=>"urn:app:linkedin", "title"=>"LinkedIn", "description"=>"professional network thingy"}}, "body"=>"Doris Tong was recommended by Nipun Dave", "bodyAnnotations"=>[{"entity"=>{"id"=>"urn:member:3851611", "title"=>"Doris Tong", "image"=>"/p/3/000/053/2e2/2d83926.jpg", "type"=>"urn:linkedin:member"}, "range"=>{"start"=>0, "end"=>10}}, {"entity"=>{"id"=>"urn:member:20031783", "title"=>"Nipun Dave", "image"=>"/p/2/000/0db/139/012129e.jpg", "type"=>"urn:linkedin:member"}, "range"=>{"start"=>30, "end"=>40}}], "socialSummary"=>{"totalComments"=>0, "recentComments"=>[], "totalLikes"=>0, "recentLikes"=>[], "likedByCurrentUser"=>false, "totalShares"=>0, "verbSummaries"=>{"urn:linkedin:like"=>{"total"=>0, "recent"=>[], "actedOnByCurrentUser"=>false}}}}

class USCPRenderer

  def self.get_template_for(verb_type)
    case verb_type
    when "assdasd"
      <<-template
      template
    else
      <<-template
        <div class="update">
          <div class="update-user">
          {{#update.actor}}
            <div class="update-photo">
              <img src="http://m2.licdn.com/mpr/mpr/shrink_80_80{{image}}" />
            </div>
          {{/update.actor}}
          </div>
          <div class="update-content">
            <div class="update-body">{{update.body}}</div>
            <ul class="update-actions">
              <li><a href="#">Like</a></li>
              <li><a href="#">Comment</a></li>
              <li class="timestamp">{{update.createdDate}}</li>
            </ul>
          </div>
        </div>
      template
    end
  end

  def self.render_feed(json_string)
    json = JSON.parse(json_string)
    updates = json["value"]
    updates_html = []
    if updates && updates.length > 0
      updates.each do |update|
        template = self.get_template_for(update["verb"]["type"])
        updates_html << Mustache.render(template, :update => update)
      end
    end
    updates_html.join("")
  end
end
