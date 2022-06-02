version_tag = ARGV[0] || "latest"

# Manual list - MAKE SURE UP TO DATE especially base images
containers = [
  { name: "ballaerospace/cosmosc2-ruby:#{version_tag}", base_image: "alpine:3.15.4", apk: true, gems: true },
  { name: "ballaerospace/cosmosc2-node:#{version_tag}", base_image: "ballaerospace/cosmosc2-ruby:#{version_tag}", apk: true },
  { name: "ballaerospace/cosmosc2-base:#{version_tag}", base_image: "ballaerospace/cosmosc2-ruby:#{version_tag}", apk: true, gems: true },
  { name: "ballaerospace/cosmosc2-cmd-tlm-api:#{version_tag}", base_image: "ballaerospace/cosmosc2-base:#{version_tag}", apk: true, gems: true },
  { name: "ballaerospace/cosmosc2-init:#{version_tag}", base_image: "ballaerospace/cosmosc2-base:#{version_tag}", apk: true, gems: true, yarn: "/cosmos/plugins/yarn.lock" },
  { name: "ballaerospace/cosmosc2-operator:#{version_tag}", base_image: "ballaerospace/cosmosc2-base:#{version_tag}", apk: true, gems: true },
  { name: "ballaerospace/cosmosc2-script-runner-api:#{version_tag}", base_image: "ballaerospace/cosmosc2-base:#{version_tag}", apk: true, gems: true },
  { name: "ballaerospace/cosmosc2-redis:#{version_tag}", base_image: "redis:6.2", apt: true },
  { name: "ballaerospace/cosmosc2-traefik:#{version_tag}", base_image: "traefik:2.6.6", apk: true },
  { name: "ballaerospace/cosmosc2-minio:#{version_tag}", base_image: "minio/minio:RELEASE.2021-06-17T00-10-46Z", rpm: true },
]

$overall_apk = []
$overall_apt = []
$overall_rpm = []
$overall_gems = []
$overall_yarn = []

def make_sorted_hash(name_versions)
  result = {}
  name_versions.sort!
  name_versions.each do |name, version, package|
    result[name] ||= [[], []]
    result[name][0] << version
    result[name][1] << package
  end
  result.each do |name, data|
    data[0].uniq!
    data[1].uniq!
  end
  result
end

def breakup_versioned_package(line, name_versions, package)
  split_line = line.split('-')
  found = false
  (split_line.length - 1).times do |index|
    i = index + 1
    if (split_line[i][0] =~ /\d/) or split_line[i -1] == 'pubkey'
      name = split_line[0..(i - 1)].join('-')
      version = split_line[i..-1].join('-')
      name_versions << [name, version, package]
      found = true
      break
    end
  end
  raise "Couldn't breakup version for #{package}" unless found
end

def extract_apk(container)
  container_name = container[:name]
  name_versions = []
  lines = `docker run --rm #{container_name} apk list -I`
  lines.each_line do |line|
    package = line.split(' ')[0]
    breakup_versioned_package(package, name_versions, package)
  end
  $overall_apk.concat(name_versions)
  make_sorted_hash(name_versions)
end

def extract_apt(container)
  container_name = container[:name]
  results = `docker run --rm #{container_name} apt list --installed`
  name_versions = []
  results.each_line do |line|
    next if line =~ /Listing/
    name = line.split("/now")[0]
    version = line.split(' ')[1]
    name_versions << [name, version, nil]
  end
  $overall_apt.concat(name_versions)
  make_sorted_hash(name_versions)
end

def extract_rpm(container)
  container_name = container[:name]
  name_versions = []
  lines = `docker run --entrypoint "" --rm #{container_name} rpm -qa`
  lines.each_line do |line|
    full_package = line.strip
    split_line = full_package.split('.')
    if split_line.length > 1
      split_line = split_line[0..-3] # Remove el8 and arch
    end
    line = split_line.join('.')
    breakup_versioned_package(line, name_versions, full_package)
  end
  $overall_rpm.concat(name_versions)
  make_sorted_hash(name_versions)
end

def extract_gems(container)
  container_name = container[:name]
  name_versions = []
  lines = `docker run --rm #{container_name} gem list --local`
  lines.each_line do |line|
    split_line = line.strip.split(' ')
    name = split_line[0]
    rest = split_line[1..-1].join(' ')
    versions = rest[1..-2]
    versions.gsub!("default: ", "")
    versions = versions.split(',')
    name_versions << [name, versions, nil]
  end
  $overall_gems.concat(name_versions)
  make_sorted_hash(name_versions)
end

def extract_yarn(container)
  container_name = container[:name]
  yarn_lock_path = container[:yarn]
  id = `docker create #{container_name}`.strip
  `docker cp #{id}:#{yarn_lock_path} .`
  `docker rm -v #{id}`
  data = File.read("yarn.lock")
  name_versions = process_yarn(data)
  $overall_yarn.concat(name_versions)
  make_sorted_hash(name_versions)
end

def process_yarn(data)
  result = []
  name = nil
  version_next = false
  data.each_line do |line|
    if version_next
      version_next = false
      version = line.split('"')[1]
      result << [name, version, nil]
    end
    if line[0] != " " and line[0] != '#' and line.strip != ""
      if line[0] == '"'
        part = line.split('"')[1]
        last_at = part.rindex('@')
        name = part[0..(last_at - 1)]
      else
        name = line.split('@')[0]
      end
      version_next = true
    end
  end
  result
end

def build_section(title, name_version_hash, show_full_packages = false)
  report = ""
  report << "#{title}:\n"
  name_version_hash.each do |name, data|
    versions = data[0]
    packages = data[1]
    if show_full_packages
      report << "  #{name} (#{versions.join(', ')}) [#{packages.join(', ')}]\n"
    else
      report << "  #{name} (#{versions.join(', ')})\n"
    end
  end
  report
end

def build_summary_report(containers)
  report = ""
  report << "COSMOS C2 Package Report Summary\n"
  report << "-" * 80
  report << "\n\nCreated: #{Time.now}\n\n"
  report << "Containers:\n"
  containers.each do |container|
    if container[:base_image]
      report << "  #{container[:name]} - Base Image: #{container[:base_image]}\n"
    else
      report << "  #{container[:name]}\n"
    end
  end
  report << "\n"
  if $overall_apk.length > 0
    report << build_section("APK Packages", make_sorted_hash($overall_apk), false)
    report << "\n"
  end
  if $overall_apt.length > 0
    report << build_section("APT Packages", make_sorted_hash($overall_apt), false)
    report << "\n"
  end
  if $overall_rpm.length > 0
    report << build_section("RPM Packages", make_sorted_hash($overall_rpm), true)
    report << "\n"
  end
  if $overall_gems.length > 0
    report << build_section("Ruby Gems", make_sorted_hash($overall_gems), false)
    report << "\n"
  end
  if $overall_yarn.length > 0
    report << build_section("Node Packages", make_sorted_hash($overall_yarn), false)
    report << "\n"
  end
  report
end

def build_container_report(container)
  report = ""
  report << "Container: #{container[:name]}\n"
  report << "Base Image: #{container[:base_image]}\n" if container[:base_image]
  report << build_section("APK Packages", extract_apk(container), false) if container[:apk]
  report << build_section("APT Packages", extract_apt(container), false) if container[:apt]
  report << build_section("RPM Packages", extract_rpm(container), true) if container[:rpm]
  report << build_section("Ruby Gems", extract_gems(container), false) if container[:gems]
  report << build_section("Node Packages", extract_yarn(container), false) if container[:yarn]
  report << "\n"
  report
end

def build_report(containers)
  report = ""
  report << "Individual Container Reports\n"
  report << "-" * 80
  report << "\n\n"
  containers.each do |container|
    report << build_container_report(container)
  end
  report
end

report = build_report(containers)
summary_report = build_summary_report(containers)

File.open("cosmosc2_package_report.txt", "w") do |file|
  file.write(summary_report)
  file.write(report)
end
