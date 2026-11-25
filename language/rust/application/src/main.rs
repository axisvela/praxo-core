mod ops;

use std::env;
use std::process;

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let tenant = value_after(&args, "--tenant").unwrap_or_else(|| "acme".to_string());
    let device = value_after(&args, "--device").unwrap_or_else(|| "device-100".to_string());
    let intent = value_after(&args, "--intent").unwrap_or_else(|| {
        "Investigate the edge gateway telemetry and draft a review-only remediation.".to_string()
    });
    let simulate_failure = args.iter().any(|arg| arg == "--simulate-failure");

    match ops::review(&tenant, &device, &intent, simulate_failure) {
        Ok(result) => {
            println!(
                "{}",
                serde_json::to_string_pretty(&result.to_json())
                    .unwrap_or_else(|_| "{}".to_string())
            );
        }
        Err(failure) => {
            println!(
                "{}",
                serde_json::to_string_pretty(&failure.to_json())
                    .unwrap_or_else(|_| "{}".to_string())
            );
            eprintln!("error: {}: {}", failure.code, failure.message);
            process::exit(if failure.code == "AGENT_POLICY_DENIED" {
                2
            } else {
                1
            });
        }
    }
}

fn value_after(args: &[String], flag: &str) -> Option<String> {
    args.windows(2)
        .find(|pair| pair[0] == flag)
        .map(|pair| pair[1].clone())
}
