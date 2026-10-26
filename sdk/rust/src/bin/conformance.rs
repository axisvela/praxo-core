fn main() {
    let failures = praxo_core::conformance::run_all();
    if failures.is_empty() {
        println!("all spec vectors passed");
        return;
    }
    for failure in &failures {
        println!("{failure}");
    }
    println!("{} vector(s) failed", failures.len());
    std::process::exit(1);
}
