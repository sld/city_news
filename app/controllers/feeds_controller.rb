#coding: utf-8

class FeedsController < ApplicationController


  def index
    if params[:city]
      text_class = TextClass.find_by_eng_name( params[:city].capitalize )
      @title = text_class.name if params[:city]
      @description = "Новости #{text_class.prepositional_name}."
      @feeds = Feed.with_text_klass( text_class.id ).order 'published_at desc'
    else
      @feeds = Feed.includes(:text_class).where('text_class_id is not null').order 'published_at desc'
    end
    @feeds = @feeds.page params[:page]
    @grouped_feeds = @feeds.where('published_at is not null').group_by{ |feed| feed.published_at.strftime("%d-%m-%Y") }
  end


  def goto
    redirect_to params[:url]
  end

end
