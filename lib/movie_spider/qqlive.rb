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
                @results << params
                @logger.info "-------- #{params.inspect}  -----  从#{@start_time}往前 已追回 #{@results.length} 个评论 --------" 
              # else
              #   @logger.info "******** id为 #{cmt['id']} 的评论已经存在 ******** 已往前追溯了#{@results.length}个评论" 
              end              
            end
            if last
              till = Time.now - @start_time
              if till <= 180  # 每次只抓取前3分钟
                get_history(last)
              end
            end
          end
        end
      end
    end
    # def abc(cid,reqnum=20,detail=nil)
    #     url  = "http://video.coral.qq.com/article/1010969500/comment?commentid=#{cid}&reqnum=#{reqnum}&tag=&callback=mainComment&_=#{Time.now.to_i}"
    #     page = get_page(url)
    #     if page.present?
    #       result = page.body.gsub('mainComment(','').gsub('})','}')
    #       result = JSON.parse(result)
    #       if result['data']
    #         retnum = result['data']['retnum'].to_i
    #         if retnum > 0
    #           comment_arr = result['data']['commentid']
    #           comment_arr = comment_arr.sort_by{|e| e['id']}
    #           if detail

    #           end
    #           comment_arr.each do |cmt|
    #             unless @global_hash.has_key?("#{cmt['id']}".to_sym)
    #               unless detail
    #                 @global_hash["#{cmt['id']}".to_sym] = true
    #               end
    #               params = {
    #                 cmt_id: cmt['id'],
    #                 up:cmt['up'],
    #                 rep:cmt['rep'],
    #                 time: Time.at(cmt['time'].to_i),
    #                 cont: cmt['content'],
    #                 nick: cmt['userinfo']['nick'],
    #                 gender: cmt['userinfo']['gender'],
    #                 region: cmt['userinfo']['region']
    #               }
    #               @results << params
    #               @logger.info "-------- 共有 #{@results.length} 个评论 --------"  
    #             else
    #               @logger.info "******** commentid为#{cid} 查询到id为#{cmt['id']} 的评论已经存在 评论于 #{Time.at(cmt['time'].to_i)} ********  共有 #{@results.length} 个评论  共有#{@global_hash.length}个commentid  共有#{@global_hash.select{|k,v| v == true}.length}个没有跑的commentid"
    #             end
    #           end
    #           last = result['data']['last']
    #           abc(last,20,detail)
    #         else
    #           if @global_hash.has_value?(true)
    #             wait_hash = @global_hash.select{|k,v| v == true}
    #             wait_hash.each do |k,v|
    #               @global_hash["#{k}".to_sym] = false
    #               abc(k,20,'detail')
    #             end
    #           end
    #         end
    #       end
    #     end
    # end




    # def start_crawl
    #   @agent = get_agent
    #   # cmtid = 0
    #   cmtid = '6020555996958192638'
    #   get_first_level_info(cmtid,20)
    #   @logger.info  '------'
    #   @logger.info @first_level_ids.keys.inspect
    #   @logger.info  '------'
    #   # @first_level_ids.keys.each do |cid|
    #   #   get_inner_info(cid,50)
    #   # end
    # end

    # def get_first_level_info(cmtid,reqnum=50)
    #   url  = "http://video.coral.qq.com/article/1010969500/comment?commentid=#{cmtid}&reqnum=#{reqnum}&tag=&callback=mainComment&_=#{Time.now.to_i}"
    #   page = get_page(url)
    #   if page.present?
    #     result = page.body.gsub('mainComment(','').gsub('})','}')
    #     result = JSON.parse(result)

    #     if result['data']
    #       retnum  = result['data']['retnum'].to_i
    #       hasnext = result['data']['hasnext']
    #       last    = result['data']['last'] 
    #       @logger.info "=========#{last}======"
    #       if retnum > 0
    #         comment_arr = result['data']['commentid']
    #         # comment_arr = comment_arr.sort_by{|e| e['id']}
    #         comment_arr.each do |cmt|
    #           unless @first_level_ids.has_key?("#{cmt['id']}")
    #             @first_level_ids["#{cmt['id']}"] = true
    #             params = {
    #               cmt_id: cmt['id'],
    #               up:cmt['up'],
    #               rep:cmt['rep'],
    #               time: Time.at(cmt['time'].to_i),
    #               cont: cmt['content'],
    #               nick: cmt['userinfo']['nick'],
    #               gender: cmt['userinfo']['gender'],
    #               region: cmt['userinfo']['region']
    #             }
    #             @results << params
    #           end
    #         end
    #       end

    #       # if hasnext
    #       #   get_first_level_info(last,50)
    #       # end
    #     end        
    #   end
    # end

    # def get_inner_info(cmtid,reqnum=50)
    #   url  = "http://video.coral.qq.com/article/1010969500/comment?commentid=#{cmtid}&reqnum=#{reqnum}&tag=&callback=mainComment&_=#{Time.now.to_i}"
    #   page = get_page(url)
    #   result = page.body.gsub('mainComment(','').gsub('})','}')
    #   result = JSON.parse(result) 
    #   if result['data']
    #       retnum  = result['data']['retnum'].to_i
    #       hasnext = result['data']['hasnext']
    #       last    = result['data']['last'] 
    #       if retnum > 0
    #         comment_arr = result['data']['commentid']
    #         comment_arr = comment_arr.sort_by{|e| e['id']}
    #         comment_arr.each do |cmt|
    #           unless @inner_level_ids.has_key?("#{cmt['id']}")
    #             @inner_level_ids["#{cmt['id']}"] = true
    #             params = {
    #               cmt_id: cmt['id'],
    #               up:cmt['up'],
    #               rep:cmt['rep'],
    #               time: Time.at(cmt['time'].to_i),
    #               cont: cmt['content'],
    #               nick: cmt['userinfo']['nick'],
    #               gender: cmt['userinfo']['gender'],
    #               region: cmt['userinfo']['region']
    #             }
    #             @results << params
    #           end
    #         end
    #       end                  
    #   end     
    # end






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
