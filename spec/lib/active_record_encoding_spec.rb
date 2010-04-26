require 'spec_helper'


describe ActiveRecordEncoding::StandardClassMethods do

  describe ".external_encoding" do

    before { class TestModel < ActiveRecord::Base; end }

    context "when not given :for argument" do

      it "extends the model class with .encoding_aware_define_read_method" do
        proc {
          class TestModel
            external_encoding 'latin-1'
          end
        }.should change {
          TestModel.respond_to?(:encoding_aware_define_read_method)
        }.from(false).to(true)
      end

      it "defines @active_record_external_encoding" do
        proc {
          class TestModel
            external_encoding 'latin-1'
          end
        }.should change {
          TestModel.instance_variable_get(:@active_record_external_encoding)
        }.from(nil).to('latin-1')
      end

      it "defines @active_record_encodings" do
        proc {
          class TestModel
            external_encoding 'latin-1'
          end
        }.should change {
          TestModel.instance_variable_get(:@active_record_encodings)
        }.from(nil).to({})
      end

    end

    context "when given :for argument" do

      it "defines @active_record_encodings" do
        proc {
          class TestModel
            external_encoding 'latin-1', :for => [:a_field]
          end
        }.should change {
          TestModel.instance_variable_get(:@active_record_encodings)
        }.from(nil).to(an_instance_of(Hash))
      end

    end

  end

end
