# Copyright (C) 2010 Guy Boertje
#
#
# Mongo::JavaImpl::Collection
# Mongo::JavaImpl::Utils
#

module Mongo
  module JavaImpl
    module Collection_

      private
      def create_indexes(obj,opts)
        return @j_collection.ensureIndex("#{obj}") if obj.is_a?(String) || obj.is_a?(Symbol)
        return @j_collection.ensureIndex(to_dbobject(obj),to_dbobject(opts)) if opts.is_a?(Hash)
        @j_collection.ensureIndex(to_dbobject(obj),generate_index_name(obj),!!(opts))
      end

      def remove_documents(obj,safe)
        if safe
          wr = @j_collection.remove(to_dbobject(obj),write_concern(:safe))
        else
          wr = @j_collection.remove(to_dbobject(obj))
        end
        res = from_writeresult(wr)
        res['err'].nil? && res['n'] > 0
      end

      def insert_documents(obj,safe)
        documents = obj.is_a?(Array) ? obj : [obj]
        documents.each do |o|
          o['_id'] = Java::OrgBsonTypes::ObjectId.new unless o[:_id] || o['_id']
        end
        db_obj = to_dbobject(obj)
        puts db_obj.inspect
        if safe  && !db_obj.kind_of?(java.util.ArrayList)
          @j_collection.insert(db_obj,write_concern(:safe))
        else
          @j_collection.insert(db_obj)
        end
        documents.collect { |o| o[:_id] || o['_id'] }
      end

      def find_one_document(document,fields)
        from_dbobject @j_collection.findOne(to_dbobject(document),to_dbobject(fields))
      end

      def update_documents(selector,document,upsert,multi)
        crit = to_dbobject(selector)
        doc = to_dbobject(document)
        res = case [upsert,multi]
              when [false,true]
                @j_collection.updateMulti(crit,doc)
              when [false,false]
                @j_collection.update(crit,doc)
              else
                @j_collection.update(crit,doc,upsert,multi)
              end
        from_writeresult res
      end

      def save_document(obj, safe)
        id = obj[:_id] || obj['_id']
        obj['_id'] = id = Java::OrgBsonTypes::ObjectId.new if id.nil?
        db_obj = to_dbobject(obj)
        if safe
          @j_collection.save(db_obj,write_concern(:safe))
        else
          @j_collection.save(db_obj)
        end
        id
      end
    end
    module Utils
      def to_dbobject obj
        case obj
        when Array
          array_to_dblist obj
        when Hash
          hash_to_dbobject obj
        else
          # primitive value, no conversion necessary
          #puts "Un-handled class type [#{obj.class}]"
          obj
        end
      end

      def from_dbobject obj
        hsh = BSON::OrderedHash.new
        #hsh.merge!(JSON.parse(obj.toString))
        obj.toMap.keySet.each do |key|
          value = obj.get key
          case value
            # when I need to manipulate ObjectID objects, they should be
            # processed here and wrapped in a ruby obj with the right api
          when JMongo::BasicDBObject, JMongo::BasicDBList
            hsh[key] = from_dbobject value
          else
            hsh[key] = value
          end
        end
        hsh
      end

      private

      def hash_to_dbobject doc
        obj = JMongo::BasicDBObject.new

        doc.each_pair do |key, value|
          obj.append(key.to_s, to_dbobject(value))
        end

        obj
      end

      def array_to_dblist ary
        list = java.util.ArrayList.new
        ary.each do |ele|
          list.add to_dbobject(ele)
        end
        list
      end

      def from_writeresult obj
        hsh = BSON::OrderedHash.new
        hsh.merge!(JSON.parse(obj.toString))
      end

      def write_concern(kind=nil)
        i = case kind
        when :safe
          1
        else
          0
        end
        JMongo::WriteConcern.new(i)
      end

    end
  end
end