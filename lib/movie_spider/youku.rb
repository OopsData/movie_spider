require 'mechanize'
require 'logger'
module MovieSpider

  class Youku
    def initialize(path)
      @path    = path.gsub(/\s+/,'')
      @logger  = Logger.new(STDOUT)
      @agent   = nil
      @results = [] 
    end

    def start_crawl
      @agent        = get_agent
      if  @path.include?('show_page')
        # 官方介绍页
        urls = collect_urls
        urls.each do |hash|
          result   = get_play_info(hash)
          @results << result if result.present?
        end
      else
        if @path.include?('v_show')
          # 播放页面 由于没有官方页面,进入此处的url都是零星搜集来的,所以在这里将这些url的视频全部当做是预告片视频
          @results = get_play_info({url:@path,type:'预告片'})
        end
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
      url    = URI.encode(url.to_s.gsub(/\s+/,''))
      begin
        page = @agent.get url
      rescue
        @logger.info  '-------------youku get agent.page error start -------------'
        @logger.info  @logger.info "error:#{$!} at:#{$@}"
        @logger.info  '^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^'
        @logger.info  URI.decode(url)
        @logger.info  '-------------youku get agent.page error end -------------'
      end
      return page
    end    

    # 收集url
    def collect_urls
      post_url    = get_post_url  # 海报处url
      prev_url    = get_urls('prev')
      feature_url = get_urls('feature')
      mv_url      = get_urls('mv')
      urls        = (post_url.to_a + prev_url.to_a + feature_url.to_a + mv_url.to_a).uniq
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
          url << {url:link.attr('href'),type:'预告片'} if type == 'prev'
          url << {url:link.attr('href'),type:'花絮'}   if type == 'feature'
          url << {url:link.attr('href'),type:'MV'}     if type == 'mv'
        end
      end
      return url
    end

    #获取每一个播放页面的相关信息
    def get_play_info(hash_data)
      if hash_data[:url].present?
        hash = Hash.new(0)
        res  = get_basic_doc(hash_data[:url])
        if res.present?
          vid  = get_video_id(res)
          hash[:type]          = hash_data[:type]
          hash[:title]         = res.search('#subtitle').text.gsub(/\s+/,'')
          unless hash[:title].present?
            hash[:title]       = res.search('h1.title').text.gsub(/\s+/,'')
          end
          hash[:url]           = hash_data[:url]
          hash[:commentNum]    = get_comments_count(vid)
          hash[:playNum]       = get_play_count(vid)
          hash[:upNum]         = get_up_count(res)
          hash[:downNum]       = get_down_count(res)
        end
        @logger.info '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
        @logger.info hash.inspect
        @logger.info '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
        return  hash
      end
    end


    # 获取播放页面的doc
    def get_basic_doc(url)
      uri = URI("#{url}")
      res = get_page(uri)
      return res
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
      url  = 'http://comments.youku.com/comments/~ajax/getStatus.html?__ap={"videoid":"' + vid.to_s + '"}'
      page = get_page(url)
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

    # 获取顶数量
    def get_up_count(res)
     res.search('#fn_up .num').text
    end
    # 获取踩数量
    def get_down_count(res)
     res.search('#fn_down .num').text
    end
  


  
  end
end

