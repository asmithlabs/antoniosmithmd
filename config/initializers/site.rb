SITE = YAML.load_file(Rails.root.join("config/site.yml")).with_indifferent_access.freeze
