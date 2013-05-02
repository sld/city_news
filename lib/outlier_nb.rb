class OutlierNb
  include FeedsHelper

  CITY = -1
  OUTLIER = 1

  def initialize filename="outlier-rose-nb"
    @max_test_data_count = 1000

    @filename =  "#{Rails.root}/#{filename}"
    path = @filename.split("/")[0...-1].join("/")
    FileUtils.mkdir_p(path) unless File.exists?(path)
  end


  def make_classifier
    max_test_data_count = 1000

    cities_train_data, cities_test_data = FeedsHelper.get_train_and_test_feeds(:city, true)
    cities_train_data = cities_train_data.find_all{|e| e.features_for_text_classifier.present?}

    test_data_count = cities_test_data.count
    test_data_count = max_test_data_count if test_data_count > max_test_data_count

    cities_test_data = cities_test_data.shuffle[0...test_data_count]

    outlier_data = FeedsHelper.get_train_and_test_feeds( :outlier, true )
    outlier_test_data = outlier_data[0...test_data_count]
    outlier_train_data = outlier_data[test_data_count...outlier_data.count].find_all{|e| e.features_for_text_classifier.present?}

    @nb = NaiveBayes::NaiveBayes.new 1.0, :rose, {:rose => {:duplicate_count => (outlier_train_data.count - cities_train_data.count).abs, :duplicate_klass => CITY} }

    train_data = outlier_train_data + cities_train_data
    train_data.each_with_index do |feed, i|
      puts "Training #{i}/#{train_data.count}"
      features = feed.features_for_text_classifier
      if features.empty?
        raise Exception
      else
        klass = get_klass(feed.text_class.try(:id))
        @nb.train( features, klass )
      end
    end
    FileMarshaling.marshal_save( @filename, @nb.export )
  end


  def get_klass( text_class_id )
    text_class_id.nil? ? OUTLIER : CITY
  end


  def preload
    import_data = FileMarshaling.marshal_load(@filename)
    @nb = NaiveBayes::NaiveBayes.new 1.0, :rose, {:rose => { :duplicate_klass => import_data[:rose_duplicate_count].keys.first, :duplicate_count => import_data[:rose_duplicate_count].values.first} }
    @nb.import!( import_data[:docs_count], import_data[:words_count], import_data[:vocabulary],
                 { :average_document_words => import_data[:average_document_words], :rose_duplicate_count => import_data[:rose_duplicate_count] }  )
  end


  # Return hash like { :outlier => [...], :good => [...] }
  def classify feeds, params={}
    classified_hash = {:outlier => [], :good => []}
    feeds.each do |feed|
      features = feed.features_for_text_classifier
      if features.empty?
        classified_hash[:outlier] << feed
      else
        classified = @nb.classify( features )[:class]
        classified == CITY ? classified_hash[:good] << feed : classified_hash[:outlier] << feed
      end
    end
    return classified_hash
  end
end