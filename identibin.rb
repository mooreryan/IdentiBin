require "fileutils"
require "systemu"
require "parse_fasta"
require "abort_if"
require "parallel"

# 0 means no new info ie zero distance
# 1 means 100 % new info distance of 1
# distance ranges from 0 to 1

include AbortIf

module CoreExtensions
  module Process
    def run_it *a, &b
      exit_status, stdout, stderr = systemu *a, &b

      puts stdout unless stdout.empty?
      $stderr.puts stderr unless stderr.empty?

      exit_status.exitstatus
    end

    def run_it! *a, &b
      exit_status = self.run_it *a, &b

      abort_unless exit_status.zero?,
                   "ERROR: non-zero exit status (#{exit_status})"

      exit_status
    end
  end
end

Process.extend CoreExtensions::Process

def clean str
  str.strip.gsub(/[^\p{Alnum}_]+/, "_").gsub(/_+/, "_")
end

def orf_id orf_name
  id = orf_name.match(/(.*)_____/)

  abort "ERROR -- Can't find id for #{orf_name}" if id.nil?

  id[1]
end

def mixed_cluster? cluster
  num_ids = cluster.map { |orf_name| orf_id orf_name }.uniq.count

  num_ids > 1
end

def get_num_mixed_clusters clusters
  clusters.map { |ary| ary.uniq }.select { |bool| bool }.count
end

def get_cluster_info uc_file
  clusters = {}
  cluster_sizes = {}
  n = 0

  File.open(uc_file).each_line do |line|
    line.chomp!

    # n+=1; STDERR.printf("READING -- %d\r", n) if (n%10000).zero?
    ary = line.split "\t"

    if line.start_with? "C" # Cluster record
      cluster_size = ary[2].to_i
      centroid = ary[8]

      abort_if cluster_sizes.has_key?(centroid),
               "Centroid '#{centroid}' has more than one 'C' record!"

      cluster_sizes[centroid] = cluster_size
      if clusters.has_key? centroid
        clusters[centroid] << centroid
      else
        clusters[centroid] = [centroid]
      end
    elsif line.start_with? "H" # Hit: query-target alignment
      seq = ary[8]
      centroid = ary[9]

      if clusters.has_key? centroid
        clusters[centroid] << seq
      else
        clusters[centroid] = [seq]
      end
    end
  end

  clusters.values
end

if ARGV.count < 4
  abort "USAGE: ruby #{__FILE__} num_threads tmpdir bin1_orfs.fa " +
        "bin2_orfs.fa [bin3_orfs.fa ...] > jawns.txt"
end
threads = ARGV.shift.to_i
outdir = ARGV.shift

FileUtils.mkdir_p outdir

outfiles = Parallel.map(ARGV, in_processes: threads) do |fname|
  clean_fname = clean File.basename(fname)

  outf = File.join outdir, "#{clean_fname}.seanie"

  num_orfs = 0

  File.open(outf, "w") do |f|
    ParseFasta::SeqFile.open(fname).each_record do |rec|
      num_orfs += 1
      clean_header = clean rec.header

      rec.header = "#{clean_fname}_____#{clean_header}"
      f.puts rec
    end
  end

  if num_orfs.zero?
    abort "FATAL -- file '#{fname}' has no data"
  end

  outf
end

usearch = `which usearch`.chomp
abort "ERROR -- you don't have usearch" if usearch.empty?


uc_files = []
puts ["b1", "b2",
      "info that b1 adds to b2 -- (1 - (num mixed clusters / total clusters with an ORF from b1)"].join "\t"
outstrings = Parallel.map(outfiles.combination(2),
                          in_processes: threads) do |f1, f2|

  File.open(File.join(outdir,
                      "sp.#{Process.pid}.log"), "a") do |logf|

    unless File.exists? f1
      logf.puts "FATAL -- file '#{f1}' does not exist"
    end

    unless File.exists? f2
      logf.puts "FATAL -- file '#{f2}' does not exist"
    end

    logf.printf "LOG -- working on #{f1}_#{f2}\n"
    outbase = File.join outdir, "#{File.basename f1}_#{File.basename f2}"

    cmd = "cat #{f1} #{f2} > #{outbase}.tmp"
    logf.printf "RUNNING -- %s\n", cmd
    Process::run_it! cmd

    unless File.exists? "#{outbase}.tmp"
      logf.puts "FATAL -- file '#{outbase}.tmp' does not exist"
    end

    cmd = "#{usearch} -quiet -cluster_fast #{outbase}.tmp -id 1.0 " +
          "-uc #{outbase}.uc"
    logf.printf "RUNNING -- %s\n", cmd
    Process::run_it! cmd

    unless File.exists? "#{outbase}.uc"
      logf.puts "FATAL -- file '#{outbase}.uc' doesn't exist"
      abort
    end

    clusters = get_cluster_info "#{outbase}.uc"

    clusters_uniq_ids =
      clusters.
      map { |ary| ary.map { |orf_name| orf_id orf_name }.uniq }

    cluster_ids = clusters_uniq_ids.flatten.uniq

    num_mixed_clusters = 0
    id_counts = Hash.new 0
    clusters_uniq_ids.each do |cluster|
      if cluster.count > 1
        num_mixed_clusters += 1
      else
        id_counts[cluster.first] += 1
      end
    end

    id_totals = cluster_ids.map { |id|
      [id, (num_mixed_clusters + id_counts[id]).to_f]
    }.to_h

    total_clusters = clusters.count.to_f

    line1 = [cluster_ids.first,
             cluster_ids.last,
             1 - (num_mixed_clusters / id_totals[cluster_ids.first])].join "\t"

    line2 = [cluster_ids.last,
             cluster_ids.first,
             1 - (num_mixed_clusters / id_totals[cluster_ids.last])].join "\t"

    # cmd = "rm #{outbase}.uc"
    # logf.printf "RUNNING -- %s\n", cmd
    # Process::run_it! cmd

    # cmd = "rm #{outbase}.tmp"
    # logf.printf "RUNNING -- %s\n", cmd
    # Process::run_it! cmd

    [line1, line2].join "\n"
  end
end

# remove the seanie files
# cmd = "rm #{outfiles.join " "}"
# STDERR.printf "RUNNING -- %s\n", cmd
# Process::run_it! cmd

puts outstrings.join "\n"
