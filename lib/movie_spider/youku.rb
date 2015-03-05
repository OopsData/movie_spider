require 'micro_spider'
require 'logger'
module MovieSpider

  class Youku
    def initialize(path)
      @path = path.gsub(/\s+/,'')
      @logger = Logger.new(STDOUT)
    end
  
    # 获取每一个播放页面的相关信息
    def get_page_info
      infos = []
      urls  = get_play_url
      urls.each do |hash|
        @logger.info  "=============>  runing youku  #{hash[:url]} <=============="
        begin
          data = start_crawl(hash)
          infos << data if data.present?          
        rescue
          @logger.info '--------------------------youku error while executing next url start--------------------------'
          @logger.info  hash[:url]
          @logger.info '--------------------------youku error while executing next url end  --------------------------'
          next
        end 
      end
      infos.delete_if{|e| e[:url] == nil }
      return infos
    end
  

    def get_play_url
      post_url    = get_post_url
      prev_url    = get_urls('prev')
      feature_url = get_urls('feature')
      mv_url      = get_urls('mv')
      urls        = (post_url + prev_url + feature_url + mv_url).uniq
      return urls
    end
  
    # 获取介绍页海报处的url
    def get_post_url
      return unless @path.include?('show_page')
      uri  = URI(@path)
      page = get_page(uri)
      if page.present?
        res = [{url:nil,type:nil}]
        link = page.search('.baseinfo .link a')
        if link.present?
          res = [{url:page.search('.baseinfo .link a').attr('href').value,type:'正片'}]   
        end      
      end

      return res
    end
  
  
    # 生成爬虫实例
    def generate_spider
      spider = MicroSpider.new
      spider.delay = 2
      return spider 
    end
  
    # 获取预告片及花絮及mv的链接地址
    def get_urls(type)
      url = [url:nil,type:nil]
      last_url = @path.split('/').last
      case type
      when 'prev'
        uri = URI("http://www.youku.com/show_around_type_2_title_%E9%A2%84%E5%91%8A%E7%89%87_#{last_url}?dt=json&__rt=1&__ro=reload_around_type_2_title_%E9%A2%84%E5%91%8A%E7%89%87")
      when 'feature'
        uri = URI("http://www.youku.com/show_around_type_3_title_%E8%8A%B1%E7%B5%AE_#{last_url}?dt=json&__rt=1&__ro=reload_around_type_3_title_%E8%8A%B1%E7%B5%AE")
      when 'mv'
        uri = URI("http://www.youku.com/show_around_type_6_title_MV_#{last_url}?dt=json&__rt=1&__ro=reload_around_type_6_title_MV")
      end 
      res = get_page(uri)
      if res.present?
        res.search('.v_title a').each do |link|
          url << {url:link.attr('href'),type:'预告片'}
        end 
      end
      return url
    end
  
    # 拿到视频id并开始抓取数据
    def get_play_info(hash_data)
      if hash_data[:url].present?
        hash = Hash.new(0)
        res  = get_basic_doc(hash_data[:url])
        if res.present?
          vid  = get_video_id(res)
          hash[:type]          = hash_data[:type]
          hash[:title]         = res.search('#subtitle').text.gsub(/\s+/,'')
          hash[:url]           = hash_data[:url]
          hash[:commentNum]    = get_comments_count(vid)
          hash[:playNum]       = get_play_count(vid)
          hash[:upNum]         = get_up_count(res)
          hash[:downNum]       = get_down_count(res)
        end
        return  hash
      end
    end  

    # 获取基本doc
    def get_basic_doc(url)
      uri = URI("#{url}")
      res = get_page(uri)
      return res
    end
  
    # 获取顶数量
    def get_up_count(res)
     res.search('#fn_up .num').text
    end
    # 获取踩数量
    def get_down_count(res)
     res.search('#fn_down .num').text
    end
    # 获取视频的id
    def get_video_id(res)
      vid = nil
      res.search('script').each do |script|
        unless script.attr('src').present?
          if script.content.include?('var videoId =')
            script.content.split('var').each do |sc|
              if sc.match(/videoId =/)  
                vid = sc.scan(/\d+/).first
              end
            end
          end
        end
      end
      return vid
    end
  
    # 获取视频的评论数量
    def get_comments_count(vid)
      url = "http://comments.youku.com/comments/~ajax/getStatus.html?__ap=%7B%22videoid%22:%22#{vid}%22%7D"
      uri = URI(url)
      page = get_page(uri)
      if page.present?
        cnt = JSON.parse(page.body)['total']
      else
        cnt = 0
      end
      return cnt
    end
  
    # 获取电影的播放量
    def get_play_count(vid)
      uri  = URI("http://v.youku.com/QVideo/~ajax/getVideoPlayInfo?__rt=1&__ro=&id=#{vid}&type=vv&catid=96")
      page = get_page(uri)

      if page.present?
        cnt = JSON.parse(page.body)['vv']
      else
        cnt = 0
      end
      return cnt
    end
    
    # 开始抓取
    def start_crawl(hash)
      data = get_play_info(hash)
    end

    def get_page(url)
      url  = url.to_s
      agent = Mechanize.new
      agent.user_agent_alias = 'Mac Safari'
      page = nil
      url  = url.gsub(/\s+/,'')
      uri = URI(url)
      begin
        ##TODO 如果请求频繁的话有可能会被拒绝,可以在这里加上sleep
        sleep(1.5)
        page = agent.get uri
      rescue
        @logger.info  '-------------youku get agent.page error start -------------'
        @logger.info  url
        @logger.info  '-------------youku get agent.page error end -------------'
      end
      return page
    end    
  end
end

