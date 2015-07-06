require 'mechanize'
require 'logger'
module MovieSpider
  class Qqlive
    def initialize
      @logger = Logger.new(STDOUT)
      @agent   = nil
      @results = []
      @global_hash = {}
      @start_time  = Time.now 
    end


    def start_crawl
      @agent = get_agent
      lastid = 0
      get_history(lastid)
      return @results
    end

    def get_history(lastid)
      url  = "http://pull.coral.qq.com/article/1010969500/comment/timeline?self=0&lastid=#{lastid}&&pageflag=1&delflag=1&reqnum=20&tag=&callback=mainComment&_=#{Time.now.to_i}"    
      page = get_page(url)
      if page.present?
        result = page.body.gsub('mainComment(','').gsub('})','}')
        result = JSON.parse(result)
        if result['data']
          retnum = result['data']['retnum'].to_i
          last   = result['data']['last'].to_i
          if retnum > 0
            comment_arr = result['data']['commentid']
            comment_arr.each do |cmt|
              unless @global_hash.has_key?("#{cmt['id']}")
                @global_hash["#{cmt['id']}"] = true
                params = {
                  cmt_id: cmt['id'],
                  up:cmt['up'],
                  rep:cmt['rep'],
                  time: Time.at(cmt['time'].to_i),
                  cont: cmt['content'],
                  nick: cmt['userinfo']['nick'],
                  gender: cmt['userinfo']['gender'],
                  region: cmt['userinfo']['region']
                }
                @logger.info params.inspect
                @logger.info "*************************#{@results.length}*********************************"
                @results << params
              end              
            end
            if last
              till = Time.now - @start_time
              if till <= 120  # 每次只抓取前2分钟
                get_history(last)
              end
            end
          end
        end
      end
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
