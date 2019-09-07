class Numpy < Formula
  desc "Package for scientific computing with Python"
  homepage "https://www.numpy.org/"
  url "https://files.pythonhosted.org/packages/b5/f4/098d2270d52b41f1bd7db9fc288aaa0400cb48c2a3e2af6fa365d9720947/numpy-2.3.4.tar.gz"
  sha256 "a7d018bfedb375a8d979ac758b120ba846a7fe764911a64465fd87b8729f4a6a"
  license "BSD-3-Clause"
  head "https://github.com/numpy/numpy.git", branch: "main"

  MKLROOT = "/opt/intel/mkl".freeze

  bottle do
    sha256 cellar: :any,                 arm64_tahoe:   "a4311ccc98dd6cc756ebaab843fec9cee968f1250bcd44b9bc0921ac3434b6a0"
    sha256 cellar: :any,                 arm64_sequoia: "4dd9587ee4bc586cadd0b78c2b818e4f82fcf82c1a9e9773a6a04b1a599b327e"
    sha256 cellar: :any,                 arm64_sonoma:  "eeab3247ddca70c32cbea630b0424c25bad966d1da180262fb0ed5582a671b4d"
    sha256 cellar: :any,                 sonoma:        "977e824561622f73f8c1a096c71641103606112dd963d4adf4d1f852fb7300eb"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "0bbe15a5a4b1d7a47ba361637f13d4d42d9dda3d247c0f0d39964eee5624f12a"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "29dda4d45665c3c480c967ebfedcae6a9df5fe37158bb46d133c200eedad89d7"
  end

  depends_on "gcc" => :build # for gfortran
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "python@3.13" => [:build, :test]
  depends_on "python@3.14" => [:build, :test]
  depends_on "openblas"

  on_linux do
    depends_on "patchelf" => :build
  end

  def pythons
    deps.map(&:to_formula)
        .select { |f| f.name.start_with?("python@") }
        .sort_by(&:version) # so scripts like `bin/f2py` use newest python
  end

  def install
    # See also:
    # https://software.intel.com/en-us/articles/numpyscipy-with-intel-mkl
    ENV["MACOSX_DEPLOYMENT_TARGET"] = "#{MacOS.version}"
    ENV.append_to_cflags "-march=native"
    ENV.append_to_cflags "-mtune=native"
    ENV.append_to_cflags "-Ofast"
    ENV.append "FCFLAGS", "-Ofast"
    ENV.append "FCFLAGS", "-fexternal-blas"

    ENV["ATLAS"] = "None" # avoid linking against Accelerate.framework
    ENV["BLAS"] = "#{MKLROOT}/lib/libmkl_blas95_ilp64.a"
    ENV["LAPACK"] = "#{MKLROOT}/lib/libmkl_lapack95_ilp64.a"
    config = mkl_config()

    Pathname("site.cfg").write config

    pythons.each do |python|
      python3 = python.opt_libexec/"bin/python"
      system python3, "-m", "pip", "install",
          *std_pip_args(build_isolation: true), "."
    end
  end

  def mkl_config
    return <<~EOS
      [ALL]
      extra_compile_args = -march=native -Ofast

      [mkl]
      library_dirs = #{MKLROOT}/lib
      include_dirs = #{MKLROOT}/include
      rpath = #{MKLROOT}/lib
      mkl_libs = mkl_rt
      lapack_libs =
    EOS
  end

  def openblas_config
    return <<~EOS
      [openblas]
      libraries = openblas
      library_dirs = #{openblas}/lib
      include_dirs = #{openblas}/include  end
    EOS
  end

  def caveats
    <<~EOS
      To run `f2py`, you may need to `brew install #{pythons.last}`
      
      You must export DYLD_LIBRARY_PATH=#{MKLROOT}/lib
      before loading numpy in order to avoid errors like
      "Library not loaded: @rpath/libmkl_rt.dylib".
    EOS
  end

  test do
    pythons.each do |python|
      python3 = python.opt_libexec/"bin/python"
      system python3, "-c", <<~PYTHON
        import numpy as np
        t = np.ones((3,3), int)
        assert t.sum() == 9
        assert np.dot(t, t).sum() == 27
      PYTHON
    end
  end
end
