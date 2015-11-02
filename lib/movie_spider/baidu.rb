#require 'micro_spider'
require 'mechanize'
require 'logger'
module MovieSpider
  class Baidu
    def initialize(word=nil,start=nil,to=nil)
      @word       = word
      @start      = start
      @to         = to
      @logger     = Logger.new(STDOUT)
      @count      = 0
      @reply      = 0
      @datas      = []
      @medias_arr = []
      @page_count = 1
    end


    # 高级搜索页面设置搜索条件并开始抓取
    def get_news
      uri   = URI("http://news.baidu.com/advanced_news.html")
      agp   = get_agent(uri)
      if agp
        @agent = agp.first
        page   = agp.last 
        search_form = page.form_with(:name => "f")
        search_form.field_with(:name => "q1").value = "#{@word}"
        search_form.radiobuttons_with(:name => 's')[1].check
        search_form.radiobuttons_with(:name => 'tn')[0].check
        search_form.field_with(:name => "begin_date").value = "#{@start}"
        search_form.field_with(:name => "end_date").value = "#{@to}"
        search_form.field_with(:name => 'rn').options[3].select
        search_form.field_with(:name => "bt").value = "#{Time.parse(@start).to_i}"
        search_form.field_with(:name => "y0").value = "#{@start.split('-').first}"
        search_form.field_with(:name => "m0").value = "#{@start.split('-')[1]}"
        search_form.field_with(:name => "d0").value = "#{@start.split('-').last}"
        search_form.field_with(:name => "y1").value = "#{@to.split('-').first}"
        search_form.field_with(:name => "m1").value = "#{@to.split('-')[1]}"
        search_form.field_with(:name => "d1").value = "#{@to.split('-').last}"
        search_form.field_with(:name => "et").value = "#{Time.parse(@to).to_i}"
        
        search_results  = @agent.submit search_form  
        # 文章量(提及量,百度的数据,但是逐个列表抓取的话数量要比这个少的多)
        hash            = Hash.new()
        hash[:total]    = search_results.search('#header_top_bar .nums').text.scan(/\d+/).join.to_i        
        result          = get_info_data(search_results)
        @datas          = []    #  一个电影数据搜索完毕,清除实例变量列表
        if hash[:total] == 0
          hash[:svg]    = 0.0
        else
          hash[:svg]    = result[:svg]
        end
        hash[:infos]    = result[:infos]
        return  hash               
      end
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
        @logger.info next_link.href
        begin
          @page_count += 1
          page       = next_link.click
          get_info_data(page)    
        rescue
          @logger.info "error:#{$!} at:#{$@}"
          puts "error:#{$!} at:#{$@}"
          retry
        end
      else
         svg = @reply.to_f / @count
         return {svg:svg,infos:@datas} 
      end
    end


    def get_detail(page)
      page.search('#content_left > ul li.result').each do |li|
        hash  = Hash.new()    
        # 标题       
        hash[:title] = li.search('.c-title').text
        begin
          # 连接地址
          link  = li.search('h3.c-title a').attr('href').to_s
        rescue
          link  = ''
        end
        hash[:link] = link
        metxt = li.search('.c-author').text
        metxt = metxt.split('  ')
        # 媒体
        hash[:media] = metxt.first

        date  = metxt.last.split(/\s+/).first
        # 日期 
        hash[:date]  = date.scan(/\d+/).join('-')
        date_arr = hash[:date].split('-')
        # 月份
        hash[:month] = date_arr.second
        # 日
        hash[:day]   = date_arr.last
        # 小时
        hash[:hour]  = metxt.last.split(/\s+/).last
        begin
          descipt  = li.search('.c-summary').text.gsub(/#{metxt}/,'')
        rescue
          descipt  = ''
        end
        c_info   = li.search('.c-summary .c-span-last .c-info').text
        
        # 网页快照信息
        hash[:descript]  = descipt
        begin
          hash[:descript]  = descipt.split(/\.\.\.\d*条相同/).first.gsub(/\.\.\.百度快照/,'') if c_info
        rescue
          hash[:descript]  = descipt
        end   
        lin   = li.search('.c-more_link')
        #转载量
        num   = 0
        #转载媒体
        hash[:medias] = []
        if lin.present?
          num           = lin.text.scan(/\d+/).first.to_i
          new_page      = @agent.get(lin.attr('href'))
          hash[:medias] = get_relay_medias(new_page)
          @medias_arr = [] # 每抓去完一条新闻的抓发媒体就清除一次实例变量列表
        end
        # 转载量
        hash[:relay]  = num
        @datas << hash
        #@logger.info hash.inspect
        puts "#{@word}  ------   第#{@page_count} 页--------共#{@count}条记录----------"
        #@logger.info('@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@')        
      end
    end

    # 获取转载媒体
    def get_relay_medias(page)
      page.search('#content_left > ul li.result .c-author').each do |media_text|
        @medias_arr << media_text.text.split('  ').first
      end
      next_link  = page.link_with(:text => '下一页>')
      if next_link
        begin
          page   = next_link.click
          get_relay_medias(page)    
        rescue
          retry
        end
      else
        return @medias_arr
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




