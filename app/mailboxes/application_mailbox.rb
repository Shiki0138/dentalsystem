# frozen_string_literal: true

class ApplicationMailbox < ActionMailbox::Base
  # 予約関連のメールをReservationMailboxへルーティング
  routing(/reservation@/i => :reservation)
  routing(/予約/i => :reservation)
  routing(/booking/i => :reservation)
  
  # その他の医療関連メールパターンも追加
  routing(/appointment/i => :reservation)
  routing(/診療/i => :reservation)
  routing(/受診/i => :reservation)
end