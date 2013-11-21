require 'bosh/director/compiled_package'

module Bosh::Director::CompiledPackage

  class CompiledPackageInserter
    def initialize(blobstore_client)
      @blobstore_client = blobstore_client
    end

    def insert(compiled_package, release_version)
      File.open(compiled_package.blob_path) do |f|
        @blobstore_client.create(f, compiled_package.blobstore_id)
      end
      package = Bosh::Director::Models::Package[fingerprint: compiled_package.package_fingerprint]
      stemcell = Bosh::Director::Models::Stemcell[sha1: compiled_package.stemcell_sha1]

      Bosh::Director::Models::CompiledPackage.create(
        blobstore_id: compiled_package.blobstore_id,
        package_id: package.id,
        stemcell_id: stemcell.id,
        sha1: compiled_package.sha1,
        dependency_key: release_version.package_dependency_key(package.name),
        build: Bosh::Director::Models::CompiledPackage.generate_build_number(package, stemcell),
      )
    end

  end
end
