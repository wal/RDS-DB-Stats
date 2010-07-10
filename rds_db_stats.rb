require 'rubygems'
require 'AWS'

# Bit of monkeypatching coz of a bug in the amazon-ec2 gem

module AWS
  module Cloudwatch
    class Base < AWS::Base

      def list_metrics
        raise ArgumentError, "Server must be monitoring.amazonaws.com" if server != 'monitoring.amazonaws.com'
        return response_generator(:action => 'ListMetrics', :params => {})
      end

      def get_metric_statistics ( options ={} )
        options = { :custom_unit => nil,
                    :dimensions => nil,
                    :end_time => Time.now(),      #req
                    :measure_name => "",          #req
                    :namespace => "AWS/EC2",
                    :period => 60,
                    :statistics => "",            # req
                    :start_time => (Time.now() - 86400), # Default to yesterday
                    :unit => "" }.merge(options)

        raise ArgumentError, ":end_time must be provided" if options[:end_time].nil?
        raise ArgumentError, ":end_time must be a Time object" if options[:end_time].class != Time
        raise ArgumentError, ":start_time must be provided" if options[:start_time].nil?
        raise ArgumentError, ":start_time must be a Time object" if options[:start_time].class != Time
        raise ArgumentError, "Server must be monitoring.amazonaws.com" if server != 'monitoring.amazonaws.com'
        raise ArgumentError, ":start_time must be before :end_time" if options[:start_time] > options[:end_time]
        raise ArgumentError, ":measure_name must be provided" if options[:measure_name].nil? || options[:measure_name].empty?
        raise ArgumentError, ":statistics must be provided" if options[:statistics].nil? || options[:statistics].empty?

        params = {
                    "CustomUnit" => options[:custom_unit],
                    'Dimensions.member.1.Name' => options['Dimensions.member.1.Name'],
                    'Dimensions.member.1.Value' => options['Dimensions.member.1.Value'],                                        
                    "EndTime" => options[:end_time].iso8601,
                    "MeasureName" => options[:measure_name],
                    "Namespace" => options[:namespace],
                    "Period" => options[:period].to_s,
                    "Statistics.member.1" => options[:statistics],
                    "StartTime" => options[:start_time].iso8601,
                    "Unit" => options[:unit]
        }

        return response_generator(:action => 'GetMetricStatistics', :params => params)
      end
    end
  end
end


if ARGV.size < 3
  puts "Usage - rds_db_stats AWS_KEY AWS_SECRET RDS_INSTANCE_ID"
  exit 
end

KEY = ARGV[0]
SECRET = ARGV[1]
RDS_INSTANCE = ARGV[2]

ONE_HOUR = 60 * 60
GB = 1024.0 * 1024.0 * 1024.0

def bytesToGB bytes
  sprintf("%.2f", (bytes /  GB)).to_f
end

cw = AWS::Cloudwatch::Base.new(:access_key_id => KEY, :secret_access_key => SECRET)

puts "Stats for #{RDS_INSTANCE}"
{'Free Storage (GB)' => 'FreeStorageSpace', 'CPU %' => 'CPUUtilization', 'Connections' => 'DatabaseConnections'}.each do |k,v|
  res = {}
  
  ['Maximum', 'Minimum'].each do |stat|
    options = {
      :measure_name => v,
      :namespace => 'AWS/RDS',
      'Dimensions.member.1.Name' => 'DBInstanceIdentifier',
      'Dimensions.member.1.Value' => RDS_INSTANCE,
      :statistics => stat,
      :start_time => (Time.now() - ONE_HOUR),
      :period => ONE_HOUR
    }
      
    resso = cw.get_metric_statistics(options)['GetMetricStatisticsResult']['Datapoints']['member'][0]
    res[stat] = resso['Unit'].eql?('Bytes') ? bytesToGB(resso[stat].to_f) : resso[stat].to_f
  end
  
  puts "#{k} : [#{res['Minimum']} - #{res['Maximum']}]"
end
