class Celero < Formula
  desc "C++ Benchmark Authoring Library/Framework"
  homepage "https://github.com/DigitalInBlue/Celero"
  url "https://github.com/DigitalInBlue/Celero/archive/v2.7.0.tar.gz"
  sha256 "4a72fe65dec6c9f36e981daaacba52e36fe3b14be19877f421c5507537c7c0ba"
  license "Apache-2.0"

  bottle do
    sha256 cellar: :any, arm64_big_sur: "da7e7fdaeb24274249335d357f45edb45f793bf9e57a5f128f4a72c1de9719e8"
    sha256 cellar: :any, big_sur:       "44e93e011f791c595575165d04ea08a75f3f4ad569f487acf2ee3448f6f36ffe"
    sha256 cellar: :any, catalina:      "50180fabca883914fd2b120cee3258ef4a58015287babb1883274c03d5be0fa6"
    sha256 cellar: :any, mojave:        "2ae8505c1415e5a9ca3b9d2d80a4f28516f311c755a0cbe809bc45b521a0169b"
    sha256 cellar: :any, high_sierra:   "c73b3bcf8fc8dfcb1df8367febe579c11b60067550500a5e94ec1ef7f279882c"
  end

  depends_on "cmake" => :build

  def install
    cmake_args = std_cmake_args + %w[
      -DCELERO_COMPILE_DYNAMIC_LIBRARIES=ON
      -DCELERO_ENABLE_EXPERIMENTS=OFF
      -DCELERO_ENABLE_TESTS=OFF
    ]
    system "cmake", ".", *cmake_args
    system "make", "install"
  end

  test do
    (testpath/"test.cpp").write <<~EOS
      #include <celero/Celero.h>
      #include <chrono>
      #include <thread>

      CELERO_MAIN

      BASELINE(DemoSleep, Baseline, 60, 1) {
        std::this_thread::sleep_for(std::chrono::microseconds(10000));
      }
      BENCHMARK(DemoSleep, HalfBaseline, 60, 1) {
        std::this_thread::sleep_for(std::chrono::microseconds(5000));
      }
      BENCHMARK(DemoSleep, TwiceBaseline, 60, 1) {
        std::this_thread::sleep_for(std::chrono::microseconds(20000));
      }
    EOS
    system ENV.cxx, "-std=c++14", "test.cpp", "-L#{lib}", "-lcelero", "-o", "test"
    system "./test"
  end
end
