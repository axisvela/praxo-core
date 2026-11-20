from conan import ConanFile
from conan.tools.cmake import CMake, CMakeToolchain, cmake_layout
from conan.tools.files import copy
from conan.tools.scm import Git
import os


class PraxoCoreCppConan(ConanFile):
    name = "praxo-core-cpp"
    version = "0.9.0"
    license = "MIT"
    homepage = "https://github.com/axisvela/praxo-core"
    url = "https://github.com/axisvela/praxo-core"
    description = "C++20 agent runtime with policy, tools, streaming, and plugin hosts"
    settings = "os", "compiler", "build_type", "arch"
    options = {"shared": [True, False], "fPIC": [True, False]}
    default_options = {"shared": False, "fPIC": True}

    def source(self):
        git = Git(self)
        git.clone(url="https://github.com/axisvela/praxo-core.git", target=".")
        git.checkout("d6af4a07f6554ed4b748dd82bdecf81d1e851b69")

    def layout(self):
        cmake_layout(self)

    def generate(self):
        tc = CMakeToolchain(self)
        tc.variables["BUILD_TESTING"] = False
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure(build_script_folder="language/cpp")
        cmake.build()

    def package(self):
        cmake = CMake(self)
        cmake.install()
        copy(self, "LICENSE", self.source_folder, os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        self.cpp_info.libs = ["praxo_cpp"]
        self.cpp_info.set_property("cmake_file_name", "praxo-cpp")
        self.cpp_info.set_property("cmake_target_name", "praxo::praxo_cpp")
