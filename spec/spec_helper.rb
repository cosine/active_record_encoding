
require "active_record"
require "active_record_encoding"


def build_test_model (class_name, ext_encoding = 'latin-1', for_fields = nil)

  external_encoding_command = "external_encoding #{ext_encoding.inspect}"
  if for_fields
    external_encoding_command << ", :for => #{for_fields.inspect}"
  end

  eval <<-EOF, __FILE__, __LINE__ + 1
    class #{class_name} < ActiveRecord::Base
      #{external_encoding_command}
    end
  EOF

end

