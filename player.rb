require 'rubygems'
require 'json'
require 'set'
require 'net/https'

# Server information
NAME = "pokerface"
KEY = "920d862bc6bc9c8def82ba608528a50c"
ID = 657393819

SANDBOX_GET = "/sandbox/current_turn"
SANDBOX_POST = "/sandbox/player_action"

URL = URI.parse('http://no-limit-code-em.com')

# GET
def game_state(http, name, id,  key)
  request = Net::HTTP::Get.new("/game_state?name=#{name}&game_id=#{id}&player_key=#{key}")
  http.request request
end

# POST
def player_action(http, name, key, action, parameter)
  request = Net::HTTP::Post.new("/player")
  request.set_form_data(:name => name, :player_key => key, :player_action => action, :parameters => parameter)
  http.request request
end

# Bot method
def poker_player(http, name, id, key)

  # Infinite Loop
  while true 
    
    # Your client should sleep 1 second.
    sleep 1

    # GET request.
    # Ask the server "What is going on?"
    response = game_state(http, name, id, key)

    # Parse the response.
    turn_data = JSON.parse(response.body)
    action, parameter = "", ""
    
    my_chips = turn_data["stack"]

    # Logic!
    if turn_data["play"]
    
      my_rank, highest, one_kinds  = hand_rank( turn_data["hand"] )

      if turn_data["replacement"]
        action = "replacement"
        
        # Don't replace if you have good cards
        if my_rank >= 4
          parameter = ""
        elsif my_rank <= 3
          parameter = one_kinds.join("")
        end

      # Must either call, raise or fold
      elsif turn_data["min_bet"] != turn_data["bet"]
        
        # Strong Cards
        if my_rank >= 7 
          if my_chips > turn_data["min_bet"]
            action = "raise"
            parameter = my_chips
          elsif my_chips < turn_data["min_bet"]
            action = "call"
            parameter = ""
          else
            action = "call"
            parameter = turn_data["min_bet"]
          end

        # Alright Cards
        elsif my_rank >= 3  
          if turn_data["min_bet"] / Double(my_chips) * 100 <= 40
            action = "call"
            parameter = turn_data["min_bet"]
          end

        # Bad luck
        else
          action = "fold"
          parameter = ""
        end

      # Must either check, raise or fold
      elsif turn_data["min_bet"] == turn_data["bet"]

        # Strong Cards
        if my_rank >= 7 
          if my_chips > 0
            action = "raise"
            parameter = my_chips
          else
            action = "check"
            parameter = ""
          end

        # Alright Cards, raise if you have enough chips
        elsif my_rank >= 3 && my_chips > 0 
            action = "raise"
            parameter = Double(my_chips) / 100 * 25

        # LAME CARDS, come on
        else
          action = "check"
          parameter = ""
        end

      else
        action = "check"
        parameter = ""
      end

    else
      next
    end

    puts "My hand was #{turn_data["hand"]}"
    puts "I decided to #{action}"
    puts "Parameter is #{parameter}"

    # POST request to the server
    response = player_action(http, name, key, action, parameter)

  end

end

# Card ranking logic and helper functions

TABLE = { 
         "T" => 10,
         "J" => 11,
         "Q" => 12,
         "K" => 13,
         "A" => 14 
      }

def hand_rank(hand)
    ranks = card_ranks(hand)
    if straight(ranks) && flush(hand)            # straight flush
      return 8, max(ranks)

    elsif kind(4, ranks)                           # 4 of a kind
      return 7, kind(4, ranks), kind(1, ranks)

    elsif kind(3, ranks) && kind(2, ranks)        # full house
      return 6, kind(3, ranks), kind(2, ranks)

    elsif flush(hand)                              # flush
      return 5, ranks

    elsif straight(ranks)                          # straight
      return 4, max(ranks)

    elsif kind(3, ranks)                           # 3 of a kind
      return 3, kind(3, ranks), get_one_kind_indices(ranks)

    elsif two_pair(ranks)                          # 2 pair
      return 2, two_pair(ranks)[0], get_one_kind_indices(ranks)

    elsif kind(2, ranks)                           # 2 kind
      return 1, kind(2, ranks), get_one_kind_indices(ranks)

    else                                          # high card
        return 0, ranks, get_one_kind_indices(ranks)
    end
end


def card_ranks(cards)

  ranks = []
  cards.each do |card|
    ranks.push( card[0].chr )
  end

  i = 0
  while i < ranks.size
    if TABLE.key? ranks[i]
      ranks[i] = TABLE[ ranks[i] ]
    else
      ranks[i] = Integer( ranks[i] )
    end
    i += 1
  end

  ranks.sort.reverse

  if ranks == [14, 5, 4, 3, 2]
    ranks = [5, 4, 3, 2, 1]
  end

  return ranks

end

def straight(ranks)
    return (ranks.max - ranks.min == 4) && Set(ranks).size == 5
end

def flush(hand)
    suits = []
    hand.each do |card|
        if !suits.include? card[1].chr
            suits.push(card[1].chr)
        end
    end
    return suits.size == 1
end


def kind(n, ranks)
    ranks.each do |rank|
        if ranks.count(rank) == n
            return rank
        end
    end

    return nil
end

def two_pair(ranks)

    higher = kind(2, ranks)
    ranks.reverse()
    lower = kind(2, ranks)
    ranks.reverse()
    if higher != nil and lower != nil and higher != lower 
        return higher, lower
    end
    return nil
end

def get_one_kind_indices(ranks)
  arr = []
  (0..4).each do |i|

    if ranks.count(ranks[i] == 1)
      arr.push(i)
    end

  end
  return arr
end

# MAIN
TESTKEY = "e1da0cd28f9010c5b675dca0403b8837"
TESTURL = URI.parse("http://treydev-poker.herokuapp.com")
TESTNAME = "booyah"

while (true)
  res = Net::HTTP.start(TESTURL.host, TESTURL.port) { |http|
    poker_player(http, TESTNAME, ID, TESTKEY)
  }
end

