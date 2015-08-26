#require 'micro_spider'
require 'mechanize'
require 'logger'
module MovieSpider
  class Tball
    def initialize(word=nil)
      @word       = word
      @logger     = Logger.new(STDOUT)
      @links      = []
      @results    = []
    end


    # 高级搜索页面设置搜索条件并开始抓取
    def start_crawl
      uri      = URI.decode("http://tieba.baidu.com/f/search/res?ie=utf-8&qw=#{@word}")
      @agent   = get_agent
      page     = @agent.get(uri)
      page     = page.link_with(:text => '只看主题贴').click
      get_links(page)
      get_post_info
      return @results
    end

    def get_links(page)
      page.search('.s_post').each do |post|
        @links << 'http://tieba.baidu.com' + post.search('a.bluelink').attr('href').value
      end
      begin 
        pg = page.link_with(:text => '下一页>').click
      rescue

      end
      
      get_links(pg) if pg.present?
    end

    def get_post_info
      @links.uniq!
      @links.each do |link|
        page = @agent.get(link)
        if page.present?
          tid     = link.to_s.split('?pid').first
          if tid.include?('/p/')
            tid   = tid.split('/p/').last
          end          
          page404 = page.search('body.page404')
          unless  page404.present?
            begin 
              title  = page.search(".core_title_txt").attr('title').value
            rescue
              title  = '' # 没有标题，可能是图片贴
            end
            
            
            reply  = page.search(".pb_footer .l_posts_num:first .l_reply_num .red:first").text
            basic  = {} # 盛放主题帖基本信息
            page.search(".l_post").each do |post|
              begin
                info     = JSON.parse(post.attr('data-field'))
              rescue
                next
              end
  
              cont     = post.search(".d_post_content_main .d_post_content").text
              date     = info['content']['date']
              date     = post.search('.post-tail-wrap span.tail-info:last').text unless date.present?
              post_id  = info['content']['post_id']
              date     = date.present? ? date.split(' ').first : ''
              if info['content']['post_no'] == 1
                #主题帖
                basic[:tid]           = tid
                basic[:author]        = {}
                basic[:title]         = title
                basic[:content]       = cont
                basic[:date]          = date
                basic[:reply]         = reply
                basic[:author][:name] = info["author"]["user_name"]
              end
              unless @results.map{|obj| obj[:tid]}.include?(basic[:tid])
                @results << basic            
              end
            end       
          end 
        end        
      end
    end


    def get_agent
      agent = Mechanize.new do |a| 
        a.follow_meta_refresh = true
        a.keep_alive = false
        a.ignore_bad_chunking = true
        a.user_agent_alias = 'Mac Safari'
        a.gzip_enabled = false
      end
      agent.user_agent_alias = 'Mac Safari'
      return agent  
    end
  end
end




