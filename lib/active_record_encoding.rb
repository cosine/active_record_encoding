#
# Copyright (c) 2009, Michael H. Buselli
# See LICENSE for details.  All other rights reserved.
#
#######

#
# ActiveRecordEncoding — Module to make ActiveRecord aware of Unicode
# encoding issues.
#
# ActiveRecordEncoding keeps two variables on the default encoding to
# use when accessing the database.
#
#   ActiveRecordEncoding.external_encoding = 'ISO-8859-1'
#   ActiveRecordEncoding.internal_encoding = 'UTF-8'
#
# If the external_encoding is not explicitly set then no conversions
# will be done.  The internal_encoding value defaults to
# Encoding.default_internal if not explicitly set.
#
# The internal_encoding value is the encoding of the Strings that are
# returned by ActiveRecord from String-based columns.  The
# external_encoding value tells ActiveRecord how the database is
# encoding the data.  A conversion is done if necessary.
#
# When data is being saved back to the database, the internal_encoding
# value is ignored and the encoding of the input is used to determine
# how to encode the data in the external_encoding.
#
# Encodings may also be defined on a table-by-table basis in the model
# definition.  A future version of ActiveRecordEncoding may support
# setting the encoding on a column-by-column basis, but that is not
# currently possible.
#
module ActiveRecordEncoding

  class << self
    attr_accessor :external_encoding, :internal_encoding
  end

  #
  # Set both ActiveRecordEncoding.external_encoding and
  # ActiveRecordEncoding.internal_encoding in a single method.
  #
  #   ActiveRecordEncoding.encoding = 'UTF-8'
  #
  def encoding= (new_encoding)
    @internal_encoding = @external_encoding = new_encoding
  end
  module_function :encoding=
end



module ActiveRecordEncoding::ActiveRecordExtensionClassMethods

  #
  # Set the external_encoding value for this model class.
  #
  #   class User < ActiveRecord::Base
  #     external_encoding 'ISO-8859-1'
  #   end
  #
  # When data is retrieved from the database, it will be assumed it is
  # encoded in the given format.
  #
  def external_encoding (new_encoding)
    @active_record_external_encoding = new_encoding
  end

  #
  # Set the internal_encoding value for this model class.
  #
  #   class User < ActiveRecord::Base
  #     internal_encoding 'UTF-8'
  #   end
  #
  # When String objects are returned to the user as a result of an
  # ActiveRecord database lookup, they will be in the given format.
  #
  def internal_encoding (new_encoding)
    @active_record_internal_encoding = new_encoding
  end

  #
  # Set both the external_encoding and the internal_encoding values for
  # this model class.
  #
  #   class User < ActiveRecord::Base
  #     encoding 'UTF-8'
  #   end
  #
  # When data is retrived from the database, it will be assumed it is
  # encoded in the given format and returned in the same format.
  #
  def encoding (new_encoding)
    @active_record_external_encoding = new_encoding
    @active_record_internal_encoding = new_encoding
  end

  def active_record_external_encoding #:nodoc:
    @active_record_external_encoding ||
        ActiveRecordEncoding.external_encoding
  end

  def active_record_internal_encoding #:nodoc:
    @active_record_internal_encoding ||
        ActiveRecordEncoding.internal_encoding ||
        Encoding.default_internal ||
        Encoding.default_external ||
        'UTF-8'
  end
end


class ActiveRecord::Base #:nodoc:
  extend ActiveRecordEncoding::ActiveRecordExtensionClassMethods


  def encoding_aware_read_attribute (attr_name)
    value = pre_encoding_aware_read_attribute(attr_name)

    if value.respond_to? :encoding and value.encoding.to_s.eql?('ASCII-8BIT')
      external_encoding = self.class.active_record_external_encoding

      if external_encoding = self.class.active_record_external_encoding
        internal_encoding = self.class.active_record_internal_encoding
        value.force_encoding(external_encoding).encode!(internal_encoding)
      end
    end

    value
  end

  alias_method :pre_encoding_aware_read_attribute, :read_attribute
  alias_method :read_attribute, :encoding_aware_read_attribute


  def encoding_aware_write_attribute (attr_name, value)
    if value.respond_to? :encoding and
          external_encoding = self.class.active_record_external_encoding
      value = value.encode(external_encoding)
    end

    pre_encoding_aware_write_attribute(attr_name, value)
  end

  alias_method :pre_encoding_aware_write_attribute, :write_attribute
  alias_method :write_attribute, :encoding_aware_write_attribute
end
