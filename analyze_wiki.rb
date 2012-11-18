# -*- coding: utf-8 -*-

#
# #{target_url}で指定したサイトから
# 解析対象のURLとタイトルを抜き出して#{target_hash}に持つ。
#

require 'nokogiri'
require 'graphviz'
require 'open-uri'

target_url = "http://ja.wikipedia.org/wiki/%E3%83%AD%E3%83%83%E3%82%AF%E3%83%9F%E3%83%A5%E3%83%BC%E3%82%B8%E3%82%B7%E3%83%A3%E3%83%B3%E3%81%AE%E4%B8%80%E8%A6%A7"

# open-uriで取得したHTMLファイルをXMLで分解
doc = Nokogiri::HTML(open(target_url))

# XMLのエレメントのうち対象のものだけを取り出す
nodes = doc.css("div#mw-content-text").css("a")

#
# #{target_hash}:
# key: 対象URL, value: #{value_array}
# value_array[0]: 対象URLのタイトル
# value_array[1]: #{refered_url_list}: 対象を参照しているURLのリスト
# value_array[2]: #{refer_to_url_list}: 対象が参照しているURLのリスト
#
target_hash = {}

# 該当するdiv内にあるノードを探索してhashに詰める
nodes.each do |node|

  # タイトルがnilや空白の場合は何もしない
  if not (node['title'] == nil or node['title'].strip == "")

    # 対象のリンクが存在しない場合は何もしない
    if not (node['title'] =~ /存在しないページ/)

      # 見出しの場合は何もしない
      if not (node['title'] =~ /節を編集/)

        # #{target_hash}にvalueを詰める
        refered_url_list = []
        refer_to_url_list = []
        value_array = [node['title'],refered_url_list,refer_to_url_list]
        target_hash[node['href']] = value_array
      end
    end
  end
end

# 読取ったタイトルとURLの組合せを表示
target_hash.keys.each_with_index do |key,i|
  puts (i+1).to_s+". "+target_hash[key][0]+" "+key
end

puts "対象URLを解析開始"

target_hash.keys.each_with_index do |target_path,cont|

  puts "#{target_hash[target_path][0]}のページを解析"
  print "このページに含まれるリンク: "

  begin
    # 対象のURLを開いてbufに保持
    url = "http://ja.wikipedia.org"+target_path
    buf = "Content-type: text/html \n\n"
    open(url){ |f| buf << f.read }

    # #{buf}のなかに含まれる他のURLを探索
    target_hash.keys.each do |path2|
      if target_path == path2
        # 何もしない
      else
        # MacRuby不具合のためパッチ
        # if buf =~ Regexp.new(path2)
        splited_path = path2.split("_")
        fixed_path2 = path2
        if splited_path.size > 1
          fixed_path2 = splited_path[0]+"_"
        end
        # 正規表現で探索
        if buf =~ Regexp.new(fixed_path2)
          target_hash[path2][1] << target_path
          target_hash[target_path][2] << path2

          # 発見したリンクのtitleを表示
          print target_hash[path2][0]+", "
        end
      end
    end

    puts ""
    puts "#{cont+1}/#{target_hash.keys.size}ページが完了"
  rescue => e
    puts "ページの解析に失敗"
    puts e.message
    puts target_path
  end
end

# 完成したハッシュを出力
puts "解析結果:"
target_hash.keys.each do |k|
  puts target_hash[k][0]
  target_hash[k][1].each do |l|
    print target_hash[l][0]+", "
  end
  puts ""
  puts ""
end

name_points_list = []
target_hash.values.each do |val|
  name_points_list << [val[0],val[1].size]
end

name_points_list.sort!{ |a,b| b[1] <=> a[1] }

File.open("result.txt","w") { |f|
  name_points_list.each do |result|
    f.puts result[1].to_s+"  "+result[0]
  end
}

puts "MusicMapを出力開始"

# The Music Mapを作成
target_hash.keys.each_with_index do |target_url,cont|

  # 各ミュージシャンごとのMusicMap
  piece_of_map = GraphViz.new(:G, :type => :digraph)

  # 自分自身のノード
  node_target = piece_of_map.add_nodes( target_hash[target_url][0] )
  # 被リンク側のノード
  node_refered = []
  # 相互参照対策
  already_exist_node = {}
  target_hash[target_url][1].each do |node_url|

    node_address = piece_of_map.add_nodes( target_hash[node_url][0] )
    node_refered << node_address
    already_exist_node[node_url] = node_address
  end
  # リンクしている先のノード
  node_refer_to = []
  target_hash[target_url][2].each do |node_url|
    # 被リンク側でノードを作成済み
    if already_exist_node.has_key?(node_url)
      node_refer_to << already_exist_node[node_url]
    else
      node_refer_to << piece_of_map.add_nodes( target_hash[node_url][0] )
    end
  end

  # 被リンク->ターゲットのエッジを追加
  node_refered.each do |node|
    piece_of_map.add_edges( node, node_target )
  end
  # ターゲット->リンクのエッジを追加
  node_refer_to.each do |node|
    piece_of_map.add_edges( node_target, node )
  end

  # MusicMapを出力
  name = target_hash[target_url][0].split("(")[0] #(バンド)とかを切り取ってファイル名にする
  piece_of_map.output(:png => name+".png")

  puts "Mapを出力中... #{cont}/#{target_hash.keys.size}" if cont % 10 == 0
end

puts "END"
