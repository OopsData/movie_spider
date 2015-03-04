
require 'micro_spider'

module MovieSpider
  class Baidu
    def initialize(word=nil,start=nil,to=nil)
      @word  = word
      @start = start
      @to    = to
    end  	

    # 高级搜索页面设置搜索条件并开始抓取
    def get_news_list
      t1 = Time.now
      result = []
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

      search_results.search('#content_left > ul li.result').each do |li|
       result  = find_content(li,result)
      end

      result = get_next_page(agent,result)
      t2 = Time.now
      puts "==========> 共#{result.length}条记录 耗时:#{t2 - t1}秒 <================"
      return result
    end

    # 查找所需内容
    def find_content(li,result)
        hash  = Hash.new()
        title = li.search('h3 a').text
        begin
          link  = li.search('h3 a').attr('href').value
        rescue
          link  = ''
        end
        metxt = li.search('.c-author').text
        date  = metxt.split(/\s+/).first.scan(/\d{4}-\d{2}-\d{2}/).first
        media = metxt.split(/\s+/).first.gsub(/#{date}/,'')
        time  = metxt.gsub(/#{media}/,'')      
        sumry = li.search('.c-summary').text
        photo = sumry.split(/#{time}/).last.gsub(/百度快照/,'').gsub(/\d+条相同新闻/,'').gsub(/-/,'')
        lin   = li.search('.c-more_link')

        if lin.present?
          num   = lin.text.scan(/\d+/).first
          rep   = lin.attr('href')
        else
          num   = 0
          rep   = nil
        end
        hash[:reps]  = get_reps(rep).uniq
        hash[:title] = title
        hash[:link]  = link
        hash[:media] = media
        hash[:time]  = time
        hash[:num]   = num.to_i
        hash[:summary] = photo        
        result << hash
        return result
    end

    #获取下一页信息
    def get_next_page(agent,result)
      link = agent.page.links.find { |l| l.text == '下一页>' }
      if link.present?
        page = link.click
      end
      if page.present?
        page.search('#content_left > ul li.result').each do |li|
          result = find_content(li,result)	
        end
        get_next_page(agent,result)
      end
      return result
    end

    # 获取某条新闻的转发媒体
    def get_reps(rep)
      container = []
      if rep.present?
        uri   = URI('http://news.baidu.com/' + rep.to_s.gsub(/rn=30/,'rn=100'))
        agent = get_agent(uri)
        page  = agent.last

        page.search('#content_left  .result').each do |li|
          metxt = li.search('.c-author').text
          date  = metxt.split(/\s+/).first.scan(/\d{4}-\d{2}-\d{2}/).first
          media = metxt.split(/\s+/).first.gsub(/#{date}/,'')
          container << media.gsub(/  /,'') if media.present?
          lin   = li.search('.c-more_link')
          if lin.present?
            hrf = lin.attr('href')
            get_reps(hrf)
          end 
        end
        container = get_reps_next(page,container)
      end
      return container
    end

    def get_reps_next(page,container) 	
      link = page.links.find { |l| l.text == '下一页>' }
      if link.present?
        page = link.click
        page.search('#content_left  .result').each do |li|
          metxt = li.search('.c-author').text
          date  = metxt.split(/\s+/).first.scan(/\d{4}-\d{2}-\d{2}/).first
          media = metxt.split(/\s+/).first.gsub(/#{date}/,'')
          container << media.gsub(/  /,'') if media.present?
          lin   = li.search('.c-more_link')
          if lin.present?
            hrf = lin.attr('href')
            container = get_reps(hrf)
          end 
        end
      end
      return container
    end

    def get_agent(uri)
      agent = Mechanize.new
      agent.user_agent_alias = 'Mac Safari'
      page  = agent.get uri
      page.encoding = 'utf-8'
      return [agent,page]
    end
  end
end

#baidu = MovieSpider::Baidu.new('穹顶之下','2015-02-28','2015-03-02')
#baidu = MovieSpider::Baidu.new('雾霾','2015-02-28','2015-03-02')
#baidu = MovieSpider::Baidu.new('柴静','2015-02-28','2015-03-02')
#baidu.get_news_list





