require 'csv'
require 'set'
require 'time'
require 'hashdiff'

class MimiParser
  # REQUIRED_OPTIONS = [:csv, :dir, :mask]
  HEADER_ROW = ['hostname', 'domain', 'username', 'password', 'dumped_by', 'dumped_at', 'imported_at', 'notes']
  DEFAULT_CSV='pdiff.csv'

  def self.DEFAULT_CSV
    DEFAULT_CSV
  end

  def self.clean(hash)
    # expect hash w/ :username and :domain
    raise 'Expected cred param to be Hash class - {username: \'user\', domain: \'domain\' }' unless hash.class.equal?(Hash.new.class)
    raise 'Missing :username' unless hash.keys.include? :username
    raise 'Missing :domain' unless hash.keys.include? :domain

    u = hash[:username]
    d = hash[:domain]

    # remove username from domain if exists
    d.sub!(u, '')

    # remove training '\' for domain\user notation
    d.gsub!(/\\$/, '')

    # remove leading '@' for user@domain notation
    d.gsub!(/^@/, '')

    if d.empty?
      if u.split('\\').size == 2
        a=u.split('\\')
        hash[:domain]=a[0]
        hash[:username]=a[1]
      elsif u.split('@').size == 2
        a=u.split('@')
        hash[:username]=a[0]
        hash[:domain]=a[1]
      end
      # return hash
    else
      # domain contains a value. is it already what we expect?
      # return hash
    end

    # post cleanup
    hash[:username].downcase!
    return hash
  end

  def self.csv2hash(row)
    # hostname = row[0]
    # domain = row[1]
    # username = row[2]
    # password = row[3]
    # dumped_by = row[4]
    # dumped_at = row[5]
    # notes = row[6]
    hash = Hash.new
    if row.length == HEADER_ROW.length
      hash[:hostname] = row[0]
      hash[:domain] = row[1]
      hash[:username] = row[2]
      hash[:password] = row[3]
      hash[:dumped_by] = row[4]
      hash[:dumped_at] = row[5]
      hash[:imported_at] = row[6]
      hash[:notes] = row[7]
    end
    hash
  end

  def self.hash2csv(hash)
    csv = Array.new(HEADER_ROW.length)
    csv[0] = hash[:hostname]
    csv[1] = hash[:domain]
    csv[2] = hash[:username]
    csv[3] = hash[:password]
    csv[4] = hash[:dumped_by]
    csv[5] = hash[:dumped_at]
    csv[6] = hash[:imported_at]
    csv[7] = hash[:notes]
    # puts csv.inspect
    csv
  end

  def self.hash2key(hash)
    "#{hash[:hostname]}:#{hash[:domain]}:#{hash[:username]}:#{hash[:password]}"
  end

  def self.isValid?(hash)
    return false unless hash.keys.include?(:username) and hash.keys.include?(:domain) and hash.keys.include?(:password)
    return false if hash[:username].match(/\$$/i)
    return false if hash[:username].match(/^\(null\)$/i)
    return false if hash[:domain].match(/^\(null\)$/i)
    return false if hash[:password].match(/^\(null\)$/i)
    true
  end

  def get_creds
    read_csv
    @in_creds
  end

  def initialize
    @csv = File.join(Dir.pwd, DEFAULT_CSV)
    @csv = File.join(Dir.pwd, ENV["PDIFF_CSV"]) if ENV["PDIFF_CSV"]

    @in_creds = Hash.new
    @out_creds = Hash.new
  end

  def read_csv
    if File.file?(@csv)
      CSV.foreach(@csv) do |row|
        unless row==HEADER_ROW
          cred = MimiParser.csv2hash(row)
          key = MimiParser.hash2key(cred)
          @in_creds[key] = cred unless @in_creds.keys.include? key
        end
      end
    end
  end

  def write_csv
    CSV.open(@csv, "wb") do |csv|
      csv << HEADER_ROW
      @out_creds.values.each do |cred|
        csv << MimiParser.hash2csv(cred)
      end
    end
  end

  def run(dir,mask='*',diff=true)
    raise "Directory not specified!" if dir.nil?
    raise "Directory does not exist!" unless Dir.exists?(dir)
    pwd = Dir.pwd

    begin
      files = []
      Dir.chdir(dir)

      read_csv

      @out_creds = @in_creds.clone

      Dir[mask].select do |f|
        files << f if File.file?(f)
      end

      files.sort_by! { |c| File.stat(c).ctime }

      files.each do |f|
        # puts f
        get_lines = 0
        tmp_lines = []
        open(f) do |file|
          # puts "file: #{file.path}"

          hostname = ''
          tmp_creds = Set.new

          file.each_line do |line|
            tmp_line = line.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
            if tmp_line.match(/wdigest/i) or tmp_line.match(/kerberos/i)
              get_lines = 3
              tmp_lines = []
            else
              if get_lines > 0
                tmp_lines << tmp_line.chomp
                get_lines = get_lines - 1

                if tmp_lines.length == 3
                  tmp_cred = {}
                  # puts tmp_lines.inspect
                  tmp_lines.map do |item|
                    if item.match(/\t \* Username : /i)
                      tmp_cred[:username] = item.gsub(/\t \* Username : /i, '')
                    elsif item.match(/\t \* Domain   : /i)
                      tmp_cred[:domain] = item.gsub(/\t \* Domain   : /i, '')
                    elsif item.match(/\t \* Password : /i)
                      tmp_cred[:password] = item.gsub(/\t \* Password : /i, '')
                    end
                  end

                  hostname = tmp_cred[:username].gsub(/\$$/i, '') if tmp_cred.keys.include?(:username) and tmp_cred[:username].match(/\$$/i)
                  if MimiParser.isValid? tmp_cred
                    tmp_creds.add( MimiParser.clean(tmp_cred) )
                  end

                end
              end
            end
          end # open(f) do |file|
          # puts "hostname: #{hostname}"
          # puts "creds:"
          # puts tmp_creds.inspect

          tmp_creds.each do |cred|
            unless cred.empty?
              cred[:hostname] = hostname
              cred[:imported_at] = Time.now.utc.iso8601
              # TODO: add dumped_by
              # TODO: add dumped_at
              cred[:dumped_at] = file.atime.utc.iso8601
              key = MimiParser.hash2key(cred)
              @out_creds[key] = cred unless @out_creds.keys.include?(key)
            end
          end
        end
      end

      puts HashDiff.diff(@in_creds, @out_creds) if diff

      write_csv
    rescue Exception => e
      puts $!.to_s
      puts e.backtrace
    ensure
      Dir.chdir(pwd)
    end
  end
end
