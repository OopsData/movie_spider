require 'mechanize'
require 'logger'
module MovieSpider
  class Qqlive
    def initialize
      @logger = Logger.new(STDOUT)
      @agent   = nil
      @results = []
    end


    def get_comment_info(agent,cid,reqnum=10)
      url    = "http://coral.qq.com/article/1010969500/comment?commentid=#{cid}&reqnum=#{reqnum}&tag=&callback=mainComment&_=#{Time.now.to_i}"
      page   = get_page(url)
      if page.present?
        result = page.body.gsub('mainComment(','').gsub('})','}')
        result = JSON.parse(result)
        retnum = result['data']['retnum'].to_i
        hasnext = result['data']['hasnext']
        if retnum > 0          
          first  = result['data']['first'] # 按时间倒序第一个，即时间值最大的那个
          last   = result['data']['last']  # 按时间倒序最后一个，即时间值最小的那个
          comment_arr = result['data']['commentid']
          comment_arr = comment_arr.sort_by{|e| e['id']}
          comment_arr.each do |cmt|
            params = {
              last_id:last,
              cmt_id: cmt['id'],
              up:cmt['up'],
              rep:cmt['rep'],
              time: Time.at(cmt['time'].to_i),
              cont: cmt['content'],
              target: cmt['targetid'],
              nick: cmt['userinfo']['nick'],
              gender: cmt['userinfo']['gender'],
              region: cmt['userinfo']['region']
            }
            cmt_ids = @results.map{|hash| hash[:cmt_id]}
            unless cmt_ids.include?(params[:cmt_id])
              @results << params
              @logger.info "=====共有 #{@results.length} 个评论====="
            end
          end
          if hasnext
            get_comment_info(agent,last,20)
          end
        end
      else
        @logger.info "------- comment_id 为 #{cid} 时 get  page  出错 -------"
      end
    end


    def start_crawl
      @agent = get_agent
      cmtid = 0
      get_comment_info(@agent,cmtid,10)
      return @results
    end

    def get_agent
      @agent = Mechanize.new do |a|
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
        @logger.info  '-------------qqlive get agent.page error start -------------'
        @logger.info  @logger.info "error:#{$!} at:#{$@}"
        @logger.info  '^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^'
        @logger.info  URI.decode(url)
        @logger.info  '-------------qqllive get agent.page error end -------------'
      end
      return page
    end  
  end
end
