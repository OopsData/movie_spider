#require 'micro_spider'
require 'mechanize'
require 'logger'
module MovieSpider
  class Star
    def initialize(word=nil,start=nil,to=nil)
      @word    = word
      @start   = start
      @to      = to
      @sources = get_all_sources
      @logger  = Logger.new(STDOUT)
      @count   = 0
      @reply   = 0
      @datas   = []
    end


    def get_all_sources
      #hash = {"21cn.com"=>"21CN", "cntv.cn"=>"CCTV", "tom.com"=>"Tom", "anhuinews.com"=>"安徽在线", "beelink.com"=>"百灵网", "enorth.com.cn"=>"北方网", "lswb.com.cn"=>"北国网", "beinet.net.cn"=>"北京经济信息网", "dahe.cn"=>"大河网", "dahuawang.com"=>"大华网", "dayoo.com"=>"大洋网", "dzwww.com"=>"大众网", "dbw.cn"=>"东北网", "nen.com.cn"=>"东北新闻网", "eastday.com"=>"东方网", "gog.com.cn"=>"多彩贵州网", "ifeng.com"=>"凤凰网", "xaonline.com"=>"古城热线", "gmw.cn"=>"光明网", "gxnews.com.cn"=>"广西新闻网", "gzw.net"=>"贵州网", "gb.cri.cn"=>"国际在线", "hinews.cn"=>"海南新闻网", "cnhan.com"=>"汉网", "rednet.cn"=>"红网", "cqnews.net"=>"华龙网", "hsw.cn"=>"华商网", "sportscn.com"=>"华体网", "huaxia.com"=>"华夏经纬", "huanqiu.com"=>"环球网", "news.jsinfo.net"=>"江苏音符", "jxcn.cn"=>"江西大江网", "ycwb.com"=>"金羊网", "bjd.com.cn"=>"京报网", "longhoo.net"=>"龙虎网", "gansudaily.com.cn"=>"每日甘肃", "southcn.com"=>"南方网", "nxnews.net"=>"宁夏新闻网", "sdinfo.net"=>"齐鲁热线", "qianlong.com"=>"千龙网", "qingdaonews.com"=>"青岛新闻网", "qhnews.com"=>"青海新闻网", "people.com.cn"=>"人民网", "sxrb.com"=>"山西新闻网", "shangdu.com"=>"商都信息港", "online.sh.cn"=>"上海热线", "szonline.net"=>"深圳热线", "sznews.com"=>"深圳新闻网", "newssc.org"=>"四川新闻网", "scol.com.cn"=>"四川在线", "sohu.com"=>"搜狐", "tynews.com.cn"=>"太原新闻网", "qq.com"=>"腾讯网", "runsky.com"=>"天健网", "tianjinwe.com"=>"天津网", "ts.cn"=>"天山网", "163.com"=>"网易", "westking.cn"=>"西部在线", "xinhuanet.com"=>"新华网", "xjbs.com.cn"=>"新疆新闻在", "sina.com.cn"=>"新浪", "cnr.cn"=>"央广网", "yznews.com.cn"=>"扬州网", "hebei.com.cn"=>"长城网", "cjn.cn"=>"长江网", "zjol.com.cn"=>"浙江在线", "jcrb.com"=>"正义网", "chinajilin.com.cn"=>"中国吉林网", "jschina.com.cn"=>"中国江苏网", "cnnb.com.cn"=>"中国宁波网", "chinaqw.com"=>"中国侨网", "china.com.cn"=>"中国网", "tibet.cn"=>"中国西藏网", "china.com"=>"中华网", "cyol.com"=>"中青在线", "chinanews.com"=>"中国新闻网", "zynews.com"=>"中原网"}
      hash = {"21cn.com"=>"21CN", "cntv.cn"=>"CCTV", "tom.com"=>"Tom", "anhuinews.com"=>"安徽在线", "beelink.com"=>"百灵网", "enorth.com.cn"=>"北方网", "lswb.com.cn"=>"北国网", "beinet.net.cn"=>"北京经济信息网", "dahe.cn"=>"大河网", "dahuawang.com"=>"大华网", "dayoo.com"=>"大洋网", "dzwww.com"=>"大众网", "dbw.cn"=>"东北网", "nen.com.cn"=>"东北新闻网", "eastday.com"=>"东方网", "gog.com.cn"=>"多彩贵州网", "ifeng.com"=>"凤凰网", "xaonline.com"=>"古城热线", "gmw.cn"=>"光明网", "gxnews.com.cn"=>"广西新闻网", "gzw.net"=>"贵州网", "gb.cri.cn"=>"国际在线", "hinews.cn"=>"海南新闻网", "cnhan.com"=>"汉网", "rednet.cn"=>"红网", "cqnews.net"=>"华龙网", "hsw.cn"=>"华商网", "sportscn.com"=>"华体网", "huaxia.com"=>"华夏经纬", "huanqiu.com"=>"环球网", "news.jsinfo.net"=>"江苏音符", "jxcn.cn"=>"江西大江网", "ycwb.com"=>"金羊网", "bjd.com.cn"=>"京报网", "longhoo.net"=>"龙虎网", "gansudaily.com.cn"=>"每日甘肃", "southcn.com"=>"南方网", "nxnews.net"=>"宁夏新闻网", "sdinfo.net"=>"齐鲁热线", "qianlong.com"=>"千龙网", "qingdaonews.com"=>"青岛新闻网", "qhnews.com"=>"青海新闻网", "people.com.cn"=>"人民网", "sxrb.com" => "山西新闻网","shangdu.com"=>"商都信息港", "online.sh.cn"=>"上海热线", "szonline.net"=>"深圳热线", "sznews.com"=>"深圳新闻网", "scol.com.cn"=>"四川在线", "sohu.com"=>"搜狐", "tynews.com.cn"=>"太原新闻网", "qq.com"=>"腾讯网", "runsky.com"=>"天健网", "tianjinwe.com"=>"天津网", "ts.cn"=>"天山网", "163.com"=>"网易", "westking.cn"=>"西部在线", "xinhuanet.com"=>"新华网", "xjbs.com.cn"=>"新疆新闻在", "sina.com.cn"=>"新浪", "cnr.cn"=>"央广网", "yznews.com.cn"=>"扬州网", "hebei.com.cn"=>"长城网", "cjn.cn"=>"长江网", "zjol.com.cn"=>"浙江在线", "jcrb.com"=>"正义网", "chinajilin.com.cn"=>"中国吉林网", "jschina.com.cn"=>"中国江苏网", "cnnb.com.cn"=>"中国宁波网", "chinaqw.com"=>"中国侨网", "china.com.cn"=>"中国网", "tibet.cn"=>"中国西藏网", "china.com"=>"中华网", "cyol.com"=>"中青在线", "chinanews.com"=>"中国新闻网", "zynews.com"=>"中原网"}
      return hash      
    end


    # 高级搜索页面设置搜索条件并开始抓取
    def get_special_site_news_list
      results = []     
      sites = ['21cn.com','cntv.cn','tom.com','anhuinews.com','beelink.com','enorth.com.cn','lswb.com.cn','beinet.net.cn','dahe.cn','dahuawang.com','dayoo.com','dzwww.com','dbw.cn','nen.com.cn','eastday.com','gog.com.cn','ifeng.com','xaonline.com','gmw.cn','gxnews.com.cn','gzw.net','gb.cri.cn','hinews.cn','cnhan.com','rednet.cn','cqnews.net','hsw.cn','sportscn.com','huaxia.com','huanqiu.com','news.jsinfo.net','jxcn.cn','ycwb.com','bjd.com.cn','longhoo.net','gansudaily.com.cn','southcn.com','nxnews.net','sdinfo.net','qianlong.com','qingdaonews.com','qhnews.com','people.com.cn','sxrb.com','shangdu.com','online.sh.cn','szonline.net','sznews.com','scol.com.cn','sohu.com','tynews.com.cn','qq.com','runsky.com','tianjinwe.com','ts.cn','163.com','westking.cn','xinhuanet.com','xjbs.com.cn','sina.com.cn','cnr.cn','yznews.com.cn','hebei.com.cn','cjn.cn','zjol.com.cn','jcrb.com','chinajilin.com.cn','jschina.com.cn','cnnb.com.cn','chinaqw.com','china.com.cn','tibet.cn','china.com','cyol.com','chinanews.com','zynews.com']
      sites.each do |site|        
        hash = Hash.new(0)       
        hash["#{@sources[site]}"] = get_news_list(site)
        results  << hash
        @count   = 0
        @reply   = 0
        @datas   = []
      end
      return results
    end


    def get_news_list(site)
      @logger.info "#{@word}------------------------#{site}--------------------------------------"
      uri   = URI("http://news.baidu.com/advanced_news.html")
      agp   = get_agent(uri)  
      hash  = Hash.new(0)      
      if agp
        agent = agp.first
        page  = agp.last 
        search_form = page.form_with(:name => "f")
        search_form.field_with(:name => "q1").value = "#{@word}"
        search_form.radiobuttons_with(:name => 's')[1].check
        search_form.radiobuttons_with(:name => 'tn')[0].check
        search_form.field_with(:name => "begin_date").value = "#{@start}"
        search_form.field_with(:name => "end_date").value = "#{@to}"
        search_form.field_with(:name => 'rn').options[3].select
        search_form.field_with(:name => "q6").value = "#{site}"
        search_form.field_with(:name => "bt").value = "#{Time.parse(@start).to_i}"
        search_form.field_with(:name => "y0").value = "#{@start.split('-').first}"
        search_form.field_with(:name => "m0").value = "#{@start.split('-')[1]}"
        search_form.field_with(:name => "d0").value = "#{@start.split('-').last}"
        search_form.field_with(:name => "y1").value = "#{@to.split('-').first}"
        search_form.field_with(:name => "m1").value = "#{@to.split('-')[1]}"
        search_form.field_with(:name => "d1").value = "#{@to.split('-').last}"
        search_form.field_with(:name => "et").value = "#{Time.parse(@to).to_i}"
        search_results = agent.submit search_form
        hash[:total]  = search_results.search('#header_top_bar .nums').text.scan(/\d+/).join.to_i        
        res           = get_info_data(search_results)
        if hash[:total] == 0
          hash[:svg]    = 0.0
        else
          hash[:svg]    = res[:svg]
        end
        hash[:infos]  = res[:infos]

        @logger.info hash.inspect
      end
      return hash
    end


    def get_reply(page)
      num = 0
      page.search('#content_left  .result').each do |li|
        lin = li.search('.c-more_link')
        if lin.present?
          num   += lin.text.scan(/\d+/).first.to_i
        end        
      end
      return num
    end


    def get_info_data(page)
      #当前页面的列表总量
      @count       += page.search('#content_left > ul li.result').length
      #当前页面的转发总量
      @reply       += get_reply(page)
      #当前页面的列表中每一项的详细数据      
      get_detail(page)
      next_link    = page.link_with(:text => '下一页>')
      if next_link
        begin
          page       = next_link.click
          get_info_data(page)    
        rescue
          @logger.info "error:#{$!} at:#{$@}"
          retry
        end
      else
        svg   = @reply.to_f / @count 
        return {svg:svg,infos:@datas} 
      end
    end


    def get_detail(page)
      page.search('#content_left > ul li.result').each do |li|
        hash  = Hash.new()           
        title = li.search('.c-title').text
        begin
          link  = li.search('h3 a.c-title').attr('href').value
        rescue
          link  = ''
        end
        metxt = li.search('.c-author').text
        metxt = metxt.split('  ')
        media = metxt.first
        date  = metxt.last.split(/\s+/).first
        lin   = li.search('.c-more_link')
        if lin.present?
          #转载量
          num   = lin.text.scan(/\d+/).first
          #转载媒体
          rep   = lin.attr('href')
        else
          num   = 0
          rep   = nil
        end
        hash[:num]   = num.to_i # 转载量
        hash[:title] = title    # 标题
        # hash[:media] = media    # 标题
        hash[:date]  = date     # 时间 
        @datas << hash
        @logger.info hash.inspect
        @logger.info('@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@')        
      end
    end

    def get_agent(uri)
      agent = Mechanize.new do |a| 
        #a.follow_meta_refresh = true
        a.ignore_bad_chunking = true
        a.keep_alive = false
        a.user_agent_alias = 'Mac Safari'
      end      
      begin
        page  = agent.get uri
        page.encoding = 'utf-8'
        return [agent,page]  
      rescue 
          @logger.info "error:#{$!} at:#{$@}"
          @logger.info "============> #{uri}   出现错误 已跳过 《=============="        
        return nil
      end
      
    end
  end
end




