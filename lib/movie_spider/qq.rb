require 'mechanize'
require 'logger'
module MovieSpider
  class Qq
    def initialize(path)
      @path = path.gsub(/\s+/,'')
      @cid  = nil
      @logger = Logger.new(STDOUT)
      @agent   = nil
      @results = []
    end


    def start_crawl
      @agent        = get_agent
      if  @path.include?('detail')
        # 官方介绍页
        urls     = collect_urls
        urls     = urls[0,30] # 多余30个会报错
        @results = get_play_info(urls)
      else
        # 播放页面 由于没有官方页面,进入此处的url都是零星搜集来的,所以在这里将这些url的视频全部当做是预告片视频
        @results = get_play_info([{url:@path,type:'预告片'}])
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
        @logger.info  '-------------qq get agent.page error start -------------'
        @logger.info  @logger.info "error:#{$!} at:#{$@}"
        @logger.info  '^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^'
        @logger.info  URI.decode(url)
        @logger.info  '-------------qq get agent.page error end -------------'
      end
      return page
    end  

    # 收集url
    def collect_urls
      id          = @path.split('/').last.split('.').first
      @cid        = get_comment_id(id)
      post_url    = get_post_url(id)
      prev_url    = get_prev_url(id)
      urls        = (post_url + prev_url).uniq
      return urls
    end

    # 获取介绍页海报处的url
    def get_post_url(id)
      url   = "http://s.video.qq.com/loadplaylist?vkey=897_qqvideo_cpl_#{id}_qq&otype=json"
      page  = get_page(url)
      hash  = Hash.new(0)
      url   = []
      if page.present?
        res = page.body.split(/\(/).split(/\)/).first[0]
        res = res.gsub('QZOutputJson=','').gsub(';','')
        res = JSON.parse(res)        
        if res['video_play_list'].present? && res['video_play_list']['total_episode'].present?
          total_episode = res['video_play_list']['total_episode'].to_i
        end
        # 0 为其他网站播放源
        # 1 表示为正片
        # 大于1表示目前没有正片
        @logger.info "~~~~~~~~~~~~~~~~~~~~~~~~~~~ #{@path} ~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        if total_episode && total_episode > 0
          if total_episode == 1
            hash[:type] = '正片'
          elsif total_episode > 1
            hash[:type] = '预告片'
          end
          hash[:title]  = res['video_play_list']['playlist'][0]['title']
          hash[:url]    = res['video_play_list']['playlist'][0]['url']
        else
          @logger.info "---------------- #{@path} --------------  该影片的播放源不在腾讯 ------- 无预告列表 --------"
        end
      end
      return url
    end

    # 获取预告片及花絮及mv的链接地址
    def get_prev_url(id)
      url   = "http://s.video.qq.com/loadplaylist?otype=json&type=2&pagestart=1&num=96&id=#{id}"
      page  = get_page(url)
      hash  = Hash.new(0)
      urls  = []
      if page.present?
        res = page.body.split(/\(/).split(/\)/).first[0]
        res = res.gsub('QZOutputJson=','').gsub(';','')
        res = JSON.parse(res)
        if res.present? && res['video_play_list'].present? && res['video_play_list']['playlist'].present?
          res['video_play_list']['playlist'].each do |obj|
            urls << {url:obj['url'],title:obj['title'],type:'预告片'}
          end
        end        
      end
      return urls    
    end

    def get_play_info(urls)
      unless urls.first[:title].present?
        pg  = get_page(urls.first[:url])
        urls.first[:title] = page.search('.mod_player_title').text()
      end
      vids  = urls.map{|hash| hash[:url].split('?vid=').last}.join('|')
      url   = "http://sns.video.qq.com/tvideo/fcgi-bin/batchgetplaymount?id=#{vids}&otype=json"
      page  = get_page(url)
      if page.present?
        res = JSON.parse(page.body.gsub('QZOutputJson=','').gsub(';',''))
        if res['node'] && res['node'].length > 0
          res['node'].each do |node|
            id  = node['id'].gsub(/\s+/,'')
            tmp_hash = urls.select{|url_hash| url_hash[:url].include?("vid=#{id}")}.first
            if node['all_m'].present?
              tmp_hash.merge!({playNum:node['all_m'].to_i,tdPlayNum:node['td'].to_i,yestPlayNum:node['yest'].to_i})
            else
              tmp_hash.merge!({playNum:node['all'].to_i,tdPlayNum:node['td'].to_i,yestPlayNum:node['yest'].to_i})
            end
            tmp_hash.merge!({commentNum:get_comments_count,upNum:get_up_down_count.first,downNum:get_up_down_count.last})
          end
        end
      end
      return urls
    end

    # 获取播放页面的doc
    def get_basic_doc(url)
      uri = URI("#{url}")
      res = get_page(uri)
      return res
    end

    # 获取视频的评论数量
    def get_comments_count
      uri = URI("http://coral.qq.com/article/#{@cid}/commentnum")
      page = get_page(uri)
      if page.present?
        res  = JSON.parse(page.body)
        return res['data']['commentnum']
      else
        return 0
      end
    end

    def get_comment_id(vid)
      uri = URI("http://sns.video.qq.com/fcgi-bin/video_comment_id?otype=json&op=3&cid=#{vid}")
      page = get_page(uri)
      if page.present?
        res  = JSON.parse(page.body.gsub('QZOutputJson=','').gsub(';',''))
        return res['comment_id']  
      else
        return 0
      end
    end

    # 获取顶数量
    def get_up_down_count
      uri  = URI::decode("http://coral.qq.com/article/#{@cid}/voteinfo")
      page = get_page(uri)
      if page.present?
        res  = JSON.parse(page.body)
        begin
          res  = res['data']['subject'][0]['option']
          return [res[0]['selected'],res[1]['selected']]
        rescue
          @logger.info '-----------------tecent  error while get up and down count start -----------------'
          @logger.info "#{@path}  没有顶和踩的数据"
          @logger.info uri
          @logger.info '-----------------tecent  error while get up and down count start -----------------'
          return [0,0]
        end      
      else
        return [0,0]
      end
    end
  end
end
