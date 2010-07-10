require 'rubygems'
require 'vendor/wal/amazon-ec2/lib/AWS'

if ARGV.size < 3
  puts "Usage - rds_db_stats AWS_KEY AWS_SECRET RDS_INSTANCE_ID TIME_PERIOD_IN_MINUTES"
  exit 
end

KEY = ARGV[0]
SECRET = ARGV[1]
RDS_INSTANCE = ARGV[2]
TIME_IN_SECONDS = ARGV[3].to_i * 60

GB = 1024.0 * 1024.0 * 1024.0


def bytesToGB bytes
  sprintf("%.2f", (bytes /  GB)).to_f
end

cw = AWS::Cloudwatch::Base.new(:access_key_id => KEY, :secret_access_key => SECRET)

puts "Stats for #{RDS_INSTANCE} since #{TIME_IN_SECONDS/60} mins"
{'Free Storage (GB)' => 'FreeStorageSpace', 'CPU %' => 'CPUUtilization', 'Connections' => 'DatabaseConnections'}.each do |k,v|
  res = {}
  
  ['Maximum', 'Minimum'].each do |stat|
    options = {
      :measure_name => v,
      :namespace => 'AWS/RDS',
      :dimensions => {'DBInstanceIdentifier' => RDS_INSTANCE},
      :statistics => stat,
      :start_time => (Time.now() - TIME_IN_SECONDS),
      :period => TIME_IN_SECONDS
    }
      
    resso = cw.get_metric_statistics(options)['GetMetricStatisticsResult']['Datapoints']['member'][0]
    res[stat] = resso['Unit'].eql?('Bytes') ? bytesToGB(resso[stat].to_f) : resso[stat].to_f
  end
  
  puts "#{k} : [#{res['Minimum']} - #{res['Maximum']}]"
end
