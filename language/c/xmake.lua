set_languages("c11")
add_rules("mode.debug", "mode.release")

target("praxo_core")
    set_kind("static")
    set_basename("praxo_core")
    add_files("src/*.c")
    add_includedirs("include", "src")
    add_headerfiles("include/(**.h)")
