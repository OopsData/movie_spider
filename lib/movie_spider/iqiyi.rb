require 'mechanize'
require 'logger'
module MovieSpider

  class Iqiyi
    def initialize(path)
      @path = path.gsub(/\s+/,'')
      @logger = Logger.new(STDOUT)
      @agent   = nil
      @results = []
    end

    def start_crawl
      @agent = get_agent
      if  @path.include?('lib')
        # 官方介绍页
        urls = collect_urls
        urls.each do |hash|
          result   = get_play_info(hash)
          @results << result if result.present?
        end
      else
        # 播放页面 由于没有官方页面,进入此处的url都是零星搜集来的,所以在这里将这些url的视频全部当做是预告片视频
        @results = get_play_info({url:@path,type:'预告片'})
      end
      return @results
    end

    def get_agent
      @agent = Mechanize.new do |a| 
        #a.keep_alive = false
        a.ignore_bad_chunking = true
        a.user_agent_alias = 'Mac Safari'
      end
    end

    def get_page(url)
      page   = nil
      url    = url.to_s.gsub(/\s+/,'')
      begin
        page = @agent.get url
      rescue
        @logger.info  '-------------iqiyi get agent.page error start -------------'
        @logger.info  @logger.info "error:#{$!} at:#{$@}"
        @logger.info  '^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^'
        @logger.info  URI.decode(url)
        @logger.info  '-------------iqiyi get agent.page error end -------------'
      end
      return page
    end 

    # 收集url
    def collect_urls
      post_url      = get_post_url  # 海报处url
      prev_url      = get_urls('prev')
      urls          = (post_url.to_a + prev_url.to_a).uniq
      return urls
    end

    # 获取介绍页海报处的url
    def get_post_url
      return unless @path.include?('lib')
      uri  = URI(@path)
      page = get_page(uri)
      res = [{url:nil,type:nil}]
      if page.present?
        if page.search('.search-btn-green').text.match(/播放/)
          type = '正片'
        else
          type = '预告片'
        end    
      end
      res = [{url:page.search('.search-btn-green').attr('href').to_s,type:type}]
      return res
    end

    # 获取预告片及花絮及mv的链接地址
    def get_urls(type)
      return unless @path.include?('lib')
      uri  = URI(@path)
      page = get_page(uri)      
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
        url  = uri
        url  = url + "&page=#{page}"
        page = get_page(uri)
        if page.present?
          body = JSON.parse(page.body)       
          if body && body.length > 0 && body['data']             
            body = body['data']['html']
            html_doc = Nokogiri::HTML(body)            
            if html_doc.search('.site-piclist_info_title a').length > 0               
              html_doc.search('.site-piclist_info_title a').each do |link|
                href = link.attr('href')
                txt  = link.text                  
                if href.start_with?('http') && txt.include?(title)               
                  type = '预告片' if url.include?('p.fjsonp')
                  type = '花絮'   if url.include?('l.fjsonp')
                  urls << {url:href,type:type} unless urls.map{|e| e[:url]}.include?(href)
                end
              end            
            end                
          end
        end
      end
      return urls
    end

    def get_play_info(hash_data)
      if hash_data[:url].present?
        hash = Hash.new(0)
        res  = get_basic_doc(hash_data[:url])
        vid  = get_video_id(res)
        if res.present?
          hash[:type]          = hash_data[:type]
          hash[:title]         = res.search('h1.mod-play-tit').text.gsub(/\s+/,'')
          hash[:url]           = hash_data[:url]
          hash[:upNum]         = get_up_down_count(vid).first
          hash[:downNum]       = get_up_down_count(vid).last
          hash[:playNum]       = get_play_count(vid)
          hash[:commentNum]    = get_comments_count(res,vid) 
          @logger.info '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
          @logger.info hash.inspect
          @logger.info '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'                     
          return  hash
        end
      end   
    end

    # 获取基本doc
    def get_basic_doc(url)
      url = url.gsub('%23','#')
      res = get_page(url)
      return res
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

    # 获取电影的播放量
    def get_play_count(vid)
      uri  = URI("http://cache.video.qiyi.com/jp/pc/#{vid}/")
      page = get_page(uri)
      if page.present?
        return page.body.split(':').last.scan(/\d+/).first.to_i
      else
        return 0
      end
    end

    # 获取视频的评论数量
    def get_comments_count(res,vid)
      # 0_329488600 组成: 0 由 页面 $('#qitancommonarea').attr('data-qitancomment-qitanid')
      # 后面部分就是参数vid
      # TODO
      # tvid216 由于目前 tvid还没有查找到，所以使用了一个比较笨的方法
      begin
        pre   = res.search('#qitancommonarea').attr('data-qitancomment-qitanid').value
      rescue
        pre   = nil  
      end

      cnt     = 0

      if pre
        agent = Mechanize.new
        agent.user_agent_alias = 'Mac Safari'
        page  = nil
        cnt   = 0
        threads = []
        page    = nil
  
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
      end
      return cnt
    end
  end
end
