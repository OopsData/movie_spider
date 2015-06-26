require 'mechanize'
require 'logger'
module MovieSpider

  class Tudou
    def initialize(path)
      @path = path.gsub(/\s+/,'')
      @logger = Logger.new(STDOUT)
      @agent   = nil
      @results = []       
    end

    def start_crawl
      @agent = get_agent
      if  @path.include?('albumcover')
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
      url    = URI.encode(url.to_s.gsub(/\s+/,''))
      begin
        page = @agent.get url
      rescue
        @logger.info  '-------------tudou get agent.page error start -------------'
        @logger.info  @logger.info "error:#{$!} at:#{$@}"
        @logger.info  '^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^'
        @logger.info  URI.decode(url)
        @logger.info  '-------------tudou get agent.page error end -------------'
      end
      return page
    end

    # 收集url
    def collect_urls
      post_url    = get_post_url
      other_url   = get_other_url
      urls        = (post_url.to_a + other_url).uniq
      return urls
    end

    # 获取介绍页海报处的url
    def get_post_url
      res = []
      page = get_page(@path)
      if page.present?
        tmp = {url:page.search('.cover_img .pic a').attr('href').value}
        if page.search('.play_btn a').text().match(/播放正片/)
          tmp.merge!({type:'正片'})
        else
          tmp.merge!({type:'预告片'})
        end
        res << tmp
      end
      return res
    end

    # 获取预告片及花絮地址
    def get_other_url
      code = @path.split('/').last.split('.').first
      uri  = URI("http://www.tudou.com/albumcover/albumdata/getOtherAlbumItemInfoes.action?acode=#{code}")
      page = get_page(uri)
      prev_url = []
      JSON.parse(page.body)['previewsPlaylistItems'].each do |item|
        prev_url << {url:item['otherPlayUrl'],type:'预告片'}
      end
      feature_url = []
      JSON.parse(page.body)['featurettesItems'].each do |item|
        feature_url << {url:item['otherPlayUrl'],type:'花絮'}
      end
      return (prev_url + feature_url).uniq
    end

    #获取每一个播放页面的相关信息  
    def get_play_info(hash_data)
      if hash_data[:url].present?
        hash = Hash.new(0)
        res  = get_basic_doc(hash_data[:url])
        if res.present?
          vid  = get_video_id(res)
          if vid.present?
            hash[:type]          = hash_data[:type]
            hash[:title]         = res.search('#videoKw').text.gsub(/\s+/,'')
            hash[:url]           = hash_data[:url]
            other_info           = get_other_info(vid)
            hash[:commentNum]    = other_info.first
            hash[:playNum]       = other_info.second
            hash[:upNum]         = other_info.third
            hash[:downNum]       = other_info.fourth
          end
        end
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

    def get_video_id(res)
      iid = nil
      res.search('script').each do |script|
        unless script.attr('src').present?
          if script.content.include?('var pageConfig')
            script.content.split(',').each do |sc|
              if sc.match(/iid:/)  
                iid = sc.scan(/\d+/).first
              end
            end
          end
        end
      end
      return iid
    end

    def get_other_info(vid)
      url = "http://www.tudou.com/crp/itemSum.action?iabcdefg=#{vid}&uabcdefg=0"
      res = get_page(url)
      if res.present?
        result = []
        info   =  JSON.parse res.body
        result << info['commentNum']
        result << info['digNum']
        result << info['playNum']
        result << 0 #土豆没有踩
      end
      return result
    end
   end
end


