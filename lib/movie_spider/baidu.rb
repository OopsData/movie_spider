
require 'micro_spider'
require 'logger'
module MovieSpider
  class Baidu
    def initialize(word=nil,start=nil,to=nil)
      @word  = word
      @start = start
      @to    = to
      @logger = Logger.new(STDOUT)
      @pages = []
      @links_arr = []
    end   

    # 高级搜索页面设置搜索条件并开始抓取
    def get_news_list
      uri   = URI("http://news.baidu.com/advanced_news.html")
      agp   = get_agent(uri)
      agent = agp.first
      page  = agp.last     
      
      search_form = page.form_with :name => "f"
      search_form.field_with(:name => "q1").value = "#{@word}"
      search_form.radiobuttons_with(:name => 's')[1].check
      search_form.field_with(:name => "begin_date").value = "#{@start}"
      search_form.field_with(:name => "end_date").value = "#{@to}"
      search_form.field_with(:name => 'rn').options[3].select
      search_results = agent.submit search_form
      
      links_arr  = get_all_page_links(agent)
      @links_arr = [] # 清空@links_arr 留给子页用
      results    = get_results(links_arr,false)
      return results
    end

    # 查找每个li的内容
    def find_content(li)
        hash  = Hash.new()           
        title = li.search('h3 a').text
        begin
          link  = li.search('h3 a').attr('href').value
        rescue
          link  = ''
        end
        metxt = li.search('.c-author').text
        date  = metxt.split(/\s+/).first.scan(/\d{4}-\d{2}-\d{2}/).first
        #媒体
        media = metxt.split(/\s+/).first.gsub(/#{date}/,'')
        #时间
        time  = metxt.gsub(/#{media}/,'')      
        sumry = li.search('.c-summary').text
        #简介
        photo = sumry.split(/#{time}/).last.gsub(/百度快照/,'').gsub(/\d+条相同新闻/,'').gsub(/-/,'')
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
        if num.to_i == 0
          hash[:reps] = []
        else
          hash[:reps]  = get_reps(rep)
        end 
        hash[:num]   = num.to_i
        hash[:title] = title
        hash[:link]  = link
        hash[:media] = media
        hash[:time]  = time
        hash[:summary] = photo
        @logger.info hash.inspect
        @logger.info '--------------------------------------------------------------------------------------'    
        return hash
    end


    def get_reps(rep)
      if rep.present?
        uri   = URI('http://news.baidu.com/' + rep.to_s.gsub(/rn=30/,'rn=100'))
        agent = get_agent(uri)
        page  = agent.last
        agent = agent.first
        links = get_all_page_links(agent)
        res   = get_reps_info(agent,links,false)      
        return res
      end
    end

    def get_reps_info(agent,links,mutiple=true)
      results       = []
      threads       = []
      results      << get_reps_detail(agent.page)
      if links.length > 0
        links.each do |link|
          if mutiple
            #多线程执行 每个页面一个线程
            threads     << Thread.new{
              url       = 'http://news.baidu.com' + link
              uri       = URI(url)
              page      = get_agent(url).last
              results   << get_reps_detail(page)
            }  
          else
            # 单线程执行
            url       = 'http://news.baidu.com' + link
            uri       = URI(url)
            page      = get_agent(url).last
            results   << get_reps_detail(page)
          end
        end
        if mutiple
          threads.each { |thr| thr.join }
        end        
      end
      return results
    end

    def get_reps_detail(page)
      page.search('#content_left  .result').each do |li|
        metxt   = li.search('.c-author').text
        date    = metxt.split(/\s+/).first.scan(/\d{4}-\d{2}-\d{2}/).first
        media   = metxt.split(/\s+/).first.gsub(/#{date}/,'')

        return media.gsub(/  /,'') if media.present?
        return  ''        
      end
    end

    def get_agent(uri)
      agent = Mechanize.new
      agent.user_agent_alias = 'Mac Safari'
      page  = agent.get uri
      page.encoding = 'utf-8'
      return [agent,page]
    end

    #===========================================================================

    def get_all_page_links(agent)
      agent.page.search('#page a').each do |link|
        if link.text.match(/\d+/)
          @pages << link.text.to_i 
          @links_arr << link.attr('href')
        end
      end
      if @pages.length >= 9
        lk = agent.page.link_with(:text => "#{@pages.max}")
        if lk.present?
          page = lk.click
          get_all_page_links(agent)          
        end
      end
      return @links_arr
    end

    def get_results(links_arr,mutiple=true)
      results       = []
      threads       = []
      links_arr.each do |link|
        if mutiple
          #多线程执行 每个页面一个线程
          threads     << Thread.new{
            url       = 'http://news.baidu.com' + link
            uri       = URI(url)
            page      = get_agent(url).last
            page.search('#content_left > ul li.result').each do |li|
                results << find_content(li)                 
            end          
          }  
        else
          # 单线程执行
          url       = 'http://news.baidu.com' + link
          uri       = URI(url)
          page      = get_agent(url).last
          page.search('#content_left > ul li.result').each do |li|
            results << find_content(li)                 
          end
        end
      end
      if mutiple
        threads.each { |thr| thr.join }
      end
      return results
    end
  end
end

#baidu = MovieSpider::Baidu.new('穹顶之下','2015-02-28','2015-03-02')
#baidu = MovieSpider::Baidu.new('雾霾','2015-02-28','2015-03-02')
# baidu = MovieSpider::Baidu.new('柴静','2015-2-28','2015-3-5')
# baidu.get_news_list






