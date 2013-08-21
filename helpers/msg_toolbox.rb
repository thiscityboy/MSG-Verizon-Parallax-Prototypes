module MsgToolbox

  ###########################
  #
  #   PUBLIC METHODS
  #
  ###########################

  ##
  #
  # Send an SMS via Catapult
  #
  # Parameters:
  #   mdn - SMS destination
  #   body - content of SMS
  #   short_code - short code to use when sending SMS
  #
  # Returns:
  #   XML in response body from Catapult
  #
  ##
  def send_sms(mdn, body, short_code)
    @api_response = send_message(mdn, body, short_code)
  end

  ##
  #
  # Shorten a URL
  #
  # Parameters:
  #
  #   long_url - URL to be shortened
  #
  # Returns:
  #   short url
  #
  ##
  def shorten_url(long_url, campaign_id)
    @short_url = shorten(long_url, campaign_id)
  end

  ##
  #
  # Convenience method to clean supplied MDN of non-numerics
  #
  # Parameters:
  #
  #   mdn - mdn to be cleaned
  #
  # Returns:
  #   mdn stripped of all non-numeric characters
  #
  ##
  def clean_mdn(mdn)
    @clean_mdn =mdn.gsub(/[^0-9]/i, '')
  end

  ##
  #
  #  Find and send incentive offer to user
  #
  # Parameters:
  #   campaign_id - incentive campaign id
  #   mdn - user's phone number
  #   mp_id - mobile page id used to display offer (check the campaign's bounceback text for this ID)
  #
  # Returns:
  #   @code - incentive code found or 'NONE', indicating no offers found
  #
  ##
  def get_offers(campaign_id, mdn, short_code, mp_id)
    conn = Faraday.new
    conn.basic_auth(ENV['SPLAT_API_USER'], ENV['SPLAT_API_PASS'])
    response = conn.get "http://www.vibescm.com/api/incentive_codes/issue/#{campaign_id.to_s}.xml?mobile=#{clean_mdn(mdn)}"
    response_hash= XmlSimple.xml_in(response.body)
    if response_hash['code'].nil?
      @code = 'NONE'
    else
      @code = response_hash['code'][0]
    end
    unless short_code.nil?
      if @code == 'NONE'
         sms_body='Sorry, no offers are available at this time'
      else
         coupon_url="http://mp.vibescm.com/p/#{mp_id}?code=#{@code}"
        short_url = shorten(coupon_url)
        sms_body="For an exclusive offer click: #{short_url}?c=#{@code} Reply HELP for help, STOP to cancel-Msg&data rates may apply"
      end
      send_message(mdn, sms_body, short_code)
    end
    @code
  end

  ##
  #
  # Subscribe mdn , attribute(s)  and custom attributes to catapult campaign.
  #
  # Parameters:
  #   attribute_values - hash of attributes to capture. MDN is required
  #   custom_attributes - hash of custom attributes to create and capture. (optional)
  #   opt_in - boolean for opt_in value - true=bounceback sent; false=no bounceback
  #
  # Returns:
  #   body of response object as XML
  #
  #
  ##
  def subscribe(campaign_id, attribute_values, custom_attributes, opt_in)

    opt = opt_in ? 'invite' : 'auto'
    url = "http://www.vibescm.com/api/subscription_campaigns/#{campaign_id.to_s}/multi_subscriptions.xml"
    payload = "<?xml version='1.0' encoding='UTF-8'?><subscriptions><opt_in>#{opt}</opt_in>"

    if custom_attributes
      payload << '<create_attribute>true</create_attribute>'
    end

    payload << '<user>'
    if attribute_values[:mobile_phone]
      mdn=clean_mdn(attribute_values[:mobile_phone])
      payload << "<mobile_phone>#{mdn}</mobile_phone>"
    end
    if attribute_values[:first_name]
      payload << "<first_name type=\"string\">#{attribute_values[:first_name]}</first_name>"
    end
    if attribute_values[:last_name]
      payload << "<last_name type=\"string\">#{attribute_values[:last_name]}</last_name>"
    end
    if attribute_values[:email]
      payload << "<email type=\"string\">#{attribute_values[:email]}</email>"
    end
    if attribute_values[:birthday_on]
      payload << "<birthday_on type=\"string\">#{attribute_values[:birthday_on]}</birthday_on>"
    end
    if attribute_values[:gender]
      payload << "<gender type=\"string\">#{attribute_values[:gender]}</birthday_on>"
    end
    if attribute_values[:carrier_code]
      payload << "<carrier_code type=\"string\">#{attribute_values[:carrier_code]}</carrier_code>"
    end
    if attribute_values[:postal_code]
      payload << "<postal_code type=\"string\">#{attribute_values[:postal_code]}</postal_code>"
    end

    if custom_attributes
      payload << '<attribute_paths>'
      custom_attributes.each_pair do |key, value|
        payload << "<attribute_path>#{key.to_s}/#{value.to_s}</attribute_path>"
      end
      payload << '</attribute_paths>'
    end

    payload << '</user></subscriptions>'
    conn = Faraday.new
    conn.basic_auth(ENV['SPLAT_API_USER'], ENV['SPLAT_API_PASS'])
    @result = conn.post do |req|
      req.url url
      req.headers['Content-Type'] = 'application/xml'
      req.body = payload
    end
    @result.body
  end


  def simple_subscribe(campaign_id, mdn)
    req_payload = "<?xml version='1.0' encoding='UTF-8'?><subscription><user><mobile_phone>#{clean_mdn(mdn)}</mobile_phone></user></subscription>"
    url = "http://www.vibescm.com/api/subscription_campaigns/#{campaign_id.to_s}/subscriptions.xml"
    conn = Faraday.new
    conn.basic_auth(ENV['SPLAT_API_USER'], ENV['SPLAT_API_PASS'])
    @result = conn.post do |req|
      req.url url
      req.headers['Content-Type'] = 'application/xml'
      req.body = req_payload
    end
    @result.body
  end


  ##
  #
  # Enter a contest campaign.
  #
  # Parameters:
  #   campaign_id - campaign to enter
  #   form_values - hash of attributes to capture
  #   custom_attributes - hash of custom attributes to create and capture. (optional)
  #   short_code - used to send SMS bounceback after entry (optional)
  #
  # Returns:
  #   text of response upon entry as defined in campaign + sms
  #   or text stating they've already entered, if applicable
  #
  ##
  def enter_contest(campaign_id, form_values, custom_attributes, short_code)

    payload = '<?xml version=\'1.0\' encoding=\'UTF-8\'?><contest_entry_data>'
    if form_values[:mobile_phone]
      mdn=clean_mdn(form_values[:mobile_phone])
      payload  << "<mobile_phone>#{mdn}</mobile_phone>"
    end
    if form_values[:first_name]
      payload  << "<first_name>#{form_values[:first_name]}</first_name>"
    end
    if form_values[:last_name]
      payload  << "<last_name>#{form_values[:last_name]}</last_name>"
    end
    if form_values[:email]
      payload  << "<email>#{form_values[:email]}</email>"
    end
    if form_values[:birthday]
      payload  << "<birthday>#{form_values[:birthday]}</birthday>"
    end
    if form_values[:phone]
      payload  << "<phone>#{form_values[:phone]}</phone>"
    end
    if form_values[:street_address]
      payload  << "<street_address>#{form_values[:street_address]}</street_address>"
    end
    if form_values[:city]
      payload  << "<city>#{form_values[:city]}</city>"
    end
    if form_values[:state_code]
      payload  << "<state_code>#{form_values[:state_code]}</state_code>"
    end
    if form_values[:postal_code]
      payload  << "<postal_code>#{form_values[:postal_code]}</postal_code>"
    end
    if custom_attributes
      payload << '<custom_attributes>'
      custom_attributes.each_pair do |key, value|
        payload << "<#{key.to_s}>#{value.to_s}</#{key.to_s}>"
      end
      payload << '</custom_attributes>'
    end
    payload  <<  '</contest_entry_data>'

    conn = Faraday.new
    conn.basic_auth(ENV['SPLAT_API_USER'], ENV['SPLAT_API_PASS'])
    response = conn.post do |req|
      req.url  "http://www.vibescm.com/api/amoe/enter.xml?id=#{campaign_id}"
      req.headers['Content-Type'] = 'application/xml'
      req.body = payload
    end
    res_hash= XmlSimple.xml_in(response.body)
    if res_hash.has_key?('bad-request')
      @result =  res_hash['bad-request'][0]
    else
      @result =  res_hash['ok'][0]
    end
    if short_code
      send_message(form_values[:mdn], @result, short_code)
    end
    @result
  end

  ##
  #
  # Sign an autograph image.
  #
  # Parameters:
  #   name - name to sign image with
  #   base_image_id - ID of base image as defined in MSG-Toolbox Image API
  #
  # Returns:
  #   Error code 400, indicating name was forbidden
  #   or signed image name
  ##
  def sign_autograph(name, base_image_id)
    conn = Faraday.new
    conn.basic_auth(ENV['MSG_API_USER'], ENV['MSG_API_PASS'])
    @result = conn.get "http://msg-umami-api.herokuapp.com/api/v2.0/autograph/sign/#{base_image_id}/#{name}"
    if @result.body.include? 'restricted'
      @result=400
    else
      resp_json = JSON.parse(@result.body)
      @result = resp_json['photo']['url'].gsub('https://msg-umami-t2a.s3.amazonaws.com/autographed_images/','')
      @result = URI::encode(@result)
    end
    @result
  end

  def send_international_sms(mdn, body)
    mdn=mdn.gsub(/[^0-9]/i, '')
    conn = Faraday.new
    @result = conn.get "http://list.lumata.com/wmap/SMS.html?User=msuk_vibes&Password=v1b3s4uk&Type=SMS&Body=#{body}Vibes&Phone=#{mdn}&Sender=Vibes"
    @result.body['<html>'] = ''
    @result.body['</html>'] = ''
    @result.body['<body>'] = ''
    @result.body['</body>'] = ''
    @result.body
  end

  ##
  #  Look up Carrier for MDN
  #
  # Parameters:
  #   mdn - mobile number
  #
  # Returns:
  #   carrier code as integer
  #
  # Carrier Code   Carrier Name
  # 101   U.S. Cellular
  # 102   Verizon Wireless
  # 103   Sprint Nextel(CDMA)
  # 104   AT&T
  # 105   T-Mobile
  #
  # full list of codes:
  #   http://wiki.vibes.com/display/API/Appendix+B++-+Carrier+Codes

  def get_carrier_code(mdn)

    un = "Vibes #{ENV['SPLAT_API_USER']}"
    pw = ENV['SPLAT_API_PASS']

    conn = Faraday.new "https://api.vibesapps.com/MessageApi/mdns/#{mdn}", ssl: {verify: false}
    result = conn.get do |req|
      req.headers['Authorization'] = "#{un}:#{pw}"
    end
    doc = Nokogiri::XML(result.body)
    doc.xpath('//mdn').each do |record|
      @carrier_code = record.at('@carrier').text
    end
    @carrier_code.to_i
  end

  ###########################
  #
  #   PRIVATE METHODS
  #
  ###########################
  private

    def send_message(mdn, body, short_code)
      mdn=clean_mdn(mdn)
      req_payload = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
                    <mtMessage>
                      <destination address=\"#{mdn}\" />
                      <source address=\"#{shortcode}\" type=\"SC\" />
                      <text><![CDATA[#{body}]]></text>
                    </mtMessage>"
      conn = Faraday.new "https://api.vibesapps.com/MessageApi/mt/messages", :ssl => {:verify => false}
      conn.basic_auth(ENV['SPLAT_API_USER'], ENV['SPLAT_API_PASS'])

      response = conn.post do |req|
        req.headers['Content-Type'] = 'text/xml'
        req.body = req_payload
      end
      puts "==== sms response ==== " + response.body
      @response = response.body
    end

    def self.shorten(urlin, campaignid)
      @url = "http://trustapi.vibesapps.com/UrlShortener/api/shorten"
      @payload = {:url => urlin}

      if mdn
        @payload['recipientaltkey'] = mdn
      end

      if accountid
        @payload['accountid'] = accountid
      end

      if campaignid
        @payload['campaignid'] = campaignid
      end

      @payload['messageTemplateId']='1'
      @payload['application'] = 'MSG'

      conn = Faraday.new
      conn.basic_auth(ENV['SHORT_USER'], ENV['SHORT_PASS'])
      response = conn.post do |req|
        req.url @url
        req.headers['Content-Type'] = 'application/json'
        req.body = @payload.to_json
      end

      @result = response.body
    end

end
