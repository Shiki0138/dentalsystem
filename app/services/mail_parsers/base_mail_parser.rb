# frozen_string_literal: true

module MailParsers
  class BaseMailParser
    def parse(mail)
      raise NotImplementedError, 'Subclasses must implement parse method'
    end
    
    protected
    
    def extract_body(mail)
      # HTMLとテキストの両方から本文を抽出
      if mail.multipart?
        mail.text_part&.decoded || mail.html_part&.decoded || ''
      else
        mail.body.decoded
      end
    end
    
    def extract_html_body(mail)
      mail.html_part&.decoded if mail.multipart?
    end
    
    def extract_text_body(mail)
      mail.text_part&.decoded if mail.multipart?
    end
    
    def clean_text(text)
      # 不要な空白や改行を整理
      text.to_s.strip.gsub(/\s+/, ' ')
    end
    
    def extract_by_pattern(text, pattern)
      match = text.match(pattern)
      match[1] if match
    end
  end
end