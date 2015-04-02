#require 'micro_spider'
require 'mechanize'
require 'logger'
module MovieSpider

  class Iqiyi
    def initialize(path)
      @path = path.gsub(/\s+/,'')
      @logger = Logger.new(STDOUT)
    end
  
    # 获取每一个播放页面的相关信息
    def get_page_info
      infos = []
      urls  = get_play_url
      urls.each do |hash|
        next unless hash[:url].include?('http://www.iqiyi.com')
        @logger.info "=============>  runing iqiyi  #{hash[:url]} <=============="
        data = start_crawl(hash)
        infos << data if data.present?
      end
      infos.delete_if{|e| e[:url] == nil }
      return infos
    end
  
    def get_play_url
      urls     = []
      page     = get_page(@path)
      if page.present?
        post_url = get_post_url(page)
        # 这里暂时去掉了最新资讯的爬取
        # news_url = get_urls(page,'news')
        prev_url = get_urls(page,'prev')
        #urls     = (post_url + news_url + prev_url).uniq
        urls     = (post_url + prev_url).uniq
      end
      return urls
    end
  
    # 获取介绍页海报处的url
    def get_post_url(page)
      return unless @path.include?('lib')
        if page.search('.search-btn-green').text.match(/播放/)
          type = '正片'
        else
          type = '预告片'
        end
        res = [{url:page.search('.result_pic  a').attr('href').to_s,type:type}]
      return res
    end
  
  
    # 生成爬虫实例
    def generate_spider
      spider = MicroSpider.new
      spider.delay = 2
      return spider 
    end
  
    # 获取预告片及花絮及mv的链接地址
    def get_urls(page,type)
      title = page.search('.main_title > a').text
      entityId = page.search('.site-main-outer .site-main-inner').search('div[data-widget-movlbtab="movlbtab"]').attr('data-movlbtab-id').value
      case type
      when 'news'
        uri  = URI::encode("http://rq.video.iqiyi.com/aries/t/l.fjsonp?title=#{title}")
      when 'prev'
        uri  = URI::encode("http://rq.video.iqiyi.com/aries/t/p.fjsonp?title=#{title}&entityId=#{entityId}")
      end
      urls   = []
      1.upto(30).each do |page|
        uri  = uri + "&page=#{page}"
        page = get_page(uri)
        if page.present?
          body = JSON.parse(page.body)['data']['html']
          html_doc = Nokogiri::HTML(body)
          if html_doc.search('.site-piclist_info_title a')
            html_doc.search('.site-piclist_info_title a').each do |link|
              href = link.attr('href')
              txt  = link.text
              if href.start_with?('http') && txt.include?(title)
                urls << {url:href,type:'预告片'} unless urls.include?(href)
              end
            end            
          end        
        end
      end
      return urls
    end
  
    # 拿到视频id并开始抓取数据
    def get_play_info(hash_data)
      if hash_data[:url].present?
        hash = Hash.new(0)
        res  = get_basic_doc(hash_data[:url])
        vid  = get_video_id(res)
        if vid.present?
          hash[:type]          = hash_data[:type]
          hash[:title]         = res.search('h1.mod-play-tit').text.gsub(/\s+/,'')
          hash[:url]           = hash_data[:url]
          hash[:upNum]         = get_up_down_count(vid).first
          hash[:downNum]       = get_up_down_count(vid).last
          hash[:playNum]       = get_play_count(vid)
          hash[:commentNum]    = get_comments_count(res,vid)          
        end
        @logger.info hash.inspect
        @logger.info('**********************************************')        
        return hash
      end
    end
  
    # 获取基本doc
    def get_basic_doc(url)
      uri = URI(url)
      res = get_page(uri)
      return res
    end
  
    # 获取顶数量
    def get_up_down_count(vid)
      uri  = "http://up.video.iqiyi.com/ugc-updown/quud.do?dataid=#{vid.to_s}&type=2"
      page = get_page(uri)
      up   = 0
      down = 0
      if page.present?
        page.body.split(',').each do |data|
          up   = data.scan(/\d+/).first if data.include?('up')
          down = data.scan(/\d+/).first if data.include?('down')
        end
      end
      return [up,down]
    end

    # 获取视频的id
    def get_video_id(res)
      vid = nil
      if res.present?
        flashbox = res.search('#flashbox')
        if flashbox.present?
          vid = res.search('#flashbox').attr('data-player-tvid').value
        end
      end
      return vid
    end
  
    # 获取视频的评论数量
    def get_comments_count(res,vid)
      # 0_329488600 组成: 0 由 页面 $('#qitancommonarea').attr('data-qitancomment-qitanid')
      # 后面部分就是参数vid
      # TODO
      # tvid216 由于目前 tvid还没有查找到，所以使用了一个比较笨的方法
      pre   =res.search('#qitancommonarea').attr('data-qitancomment-qitanid').value
      agent = Mechanize.new
      agent.user_agent_alias = 'Mac Safari'
      page  = nil
      cnt   = 0
      threads = []
      page    = nil
      #TODO
      #一个专辑内的影片数量应该不会超过500,所以这里的tvid最大取到500

      1.upto(5).each_with_index do |num,idx|
        to   = (idx + 1) * 100
        from = to - 99
        threads << Thread.new{
          from.upto(to).each do |t|
            uri = URI("http://cmts.iqiyi.com/comment/tvid#{t}/#{pre}_#{vid}_hot?t=#{Time.now.to_i}")
            begin
              page = agent.get uri
              break
            rescue
              next
            end  
          end 
        }
      end

      threads.each { |thr| thr.join }

      if page.present?
        begin
          cnt  = page.body.split('}],"count":').last.split('').first.to_i
        rescue
          cnt = 0
        end
         
      else
        cnt  = 0
      end
      return cnt
    end
  
    # 获取电影的播放量
    def get_play_count(vid)
      uri  = URI("http://cache.video.qiyi.com/jp/pc/#{vid}/?callback=window.Q.__callbacks__.cbgdimt")
      page = get_page(uri)

      if page.present?
        return page.body.split(':').last.scan(/\d+/).first
      else
        return 0
      end
    end
    
    # 开始抓取
    def start_crawl(hash)
      data = get_play_info(hash)
    end

    def get_page(url)
      url  = url.to_s
      # agent = Mechanize.new

      agent = Mechanize.new do |a| 
        a.ignore_bad_chunking = true
        a.user_agent_alias = 'Mac Safari'
      end
      
      page = nil
      url  = url.gsub(/\s+/,'')
      uri = URI(url)
      #TODO 如果请求频繁的话有可能会被拒绝,可以在这里加上sleep 
      begin 
        page = agent.get uri  
      rescue
        @logger.info  '-------------iqiyi get agent.page error start -------------'
        @logger.info  url
        @logger.info '^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^'
        @logger.info "error:#{$!} at:#{$@}"
        @logger.info  '-------------iqiyi get agent.page error end -------------'
      end
      return page
    end    
  end
end

# iqiyi = MovieSpider::Iqiyi.new('http://www.iqiyi.com/lib/m_205027214.html')
# iqiyi.get_page_info
