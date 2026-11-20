set_languages("c++20")
add_rules("mode.debug", "mode.release")

target("praxo_cpp")
    set_kind("static")
    set_basename("praxo_cpp")
    add_files("src/*.cpp")
    add_includedirs("include")
    add_headerfiles("include/(**.hpp)")
