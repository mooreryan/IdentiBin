# take 3 col dist matrix and spit out a dist matrix for R

dists = {}
all = []
File.open(ARGV.first).each_line.with_index do |line, lineno|
  unless lineno.zero?
    row, col, dist = line.chomp.split "\t"
    dist = dist.to_f

    all << row << col

    unless dists.has_key? row
      dists[row] = Hash.new 0
    end

    dists[row][col] = dist
  end
end

all = all.uniq.sort

puts ["", all].flatten.join "\t"

all.each_with_index do |row, ridx|
  row_name = all[ridx]
  print row_name

  all.each do |col|
    dist = 0
    dist = dists[row][col] if dists.has_key?(row)

    printf "\t%s", dist
  end

  puts
end
