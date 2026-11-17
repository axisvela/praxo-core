#[path = "governance_support.rs"]
mod support;

use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

use praxo_core::agent::CancellationToken;
use praxo_core::tool::Registry;
use support::*;

fn run_checks() -> std::result::Result<(), String> {
    let record_calls = Arc::new(AtomicUsize::new(0));
    let parent_calls = Arc::new(AtomicUsize::new(0));
    let mut tools = Registry::new();
    tools.register(Arc::new(RecordTool {
        calls: record_calls.clone(),
    }));
    tools.register(Arc::new(ParentOnlyTool {
        calls: parent_calls.clone(),
    }));
    let root = Governor::new(root_authority(
        &["record", "parent_only"],
        &["record"],
        1,
        2,
        2,
    ));
    if root
        .delegate(vec!["parent_only".to_string()], vec![], None)
        .is_ok()
    {
        return Err("child escaped the delegable scope".to_string());
    }
    if record_calls.load(Ordering::SeqCst) != 0 || parent_calls.load(Ordering::SeqCst) != 0 {
        return Err("scope rejection produced an effect".to_string());
    }
    let child = root
        .delegate(
            vec!["record".to_string()],
            vec![],
            Some(Arc::new(RecordPolicy)),
        )
        .map_err(|error| error.to_string())?;
    child.release();

    let depth_root = Governor::new(root_authority(&["record"], &["record"], 1, 1, 2));
    let depth_child = depth_root
        .delegate(
            vec!["record".to_string()],
            vec![],
            Some(Arc::new(RecordPolicy)),
        )
        .map_err(|error| error.to_string())?;
    let mut grand_authority = depth_child.authority.clone();
    grand_authority.delegable.insert("record".to_string());
    if Governor::new(grand_authority)
        .delegate(vec!["record".to_string()], vec![], None)
        .is_ok()
    {
        return Err("delegation exceeded the depth limit".to_string());
    }
    depth_child.release();

    let child_limit = Governor::new(root_authority(&["record"], &["record"], 1, 1, 2));
    let first_child = child_limit
        .delegate(
            vec!["record".to_string()],
            vec![],
            Some(Arc::new(RecordPolicy)),
        )
        .map_err(|error| error.to_string())?;
    if child_limit
        .delegate(vec!["record".to_string()], vec![], None)
        .is_ok()
    {
        return Err("delegation exceeded the child limit".to_string());
    }
    first_child.release();
    child_limit
        .delegate(vec!["record".to_string()], vec![], None)
        .map_err(|error| error.to_string())?
        .release();

    let budget_calls = Arc::new(AtomicUsize::new(0));
    let mut budget_tools = Registry::new();
    budget_tools.register(Arc::new(RecordTool {
        calls: budget_calls.clone(),
    }));
    let budget_root = Governor::new(root_authority(&["record"], &["record"], 1, 2, 1));
    let first = budget_root
        .delegate(
            vec!["record".to_string()],
            vec![],
            Some(Arc::new(RecordPolicy)),
        )
        .map_err(|error| error.to_string())?;
    let second = budget_root
        .delegate(
            vec!["record".to_string()],
            vec![],
            Some(Arc::new(RecordPolicy)),
        )
        .map_err(|error| error.to_string())?;
    first
        .run(
            Arc::new(FixtureModel {
                tool_name: "record".to_string(),
                arguments: args("first"),
                completion: "first-done".to_string(),
            }),
            &budget_tools,
            "record once",
            None,
            Vec::new(),
        )
        .map_err(|error| format!("first budget run failed: {}", error.message))?;
    let error = second
        .run(
            Arc::new(FixtureModel {
                tool_name: "record".to_string(),
                arguments: args("second"),
                completion: "second-done".to_string(),
            }),
            &budget_tools,
            "record twice",
            None,
            Vec::new(),
        )
        .expect_err("sibling budget must deny the second effect");
    if error.code != "DELEGATION_BUDGET" {
        return Err(format!("unexpected budget error: {}", error.code));
    }
    if budget_calls.load(Ordering::SeqCst) != 1 {
        return Err("sibling budget produced extra effects".to_string());
    }
    first.release();
    second.release();

    let cancel_calls = Arc::new(AtomicUsize::new(0));
    let mut cancel_tools = Registry::new();
    cancel_tools.register(Arc::new(RecordTool {
        calls: cancel_calls.clone(),
    }));
    let cancel_root = Governor::new(root_authority(&["record"], &["record"], 1, 1, 1));
    let canceled = cancel_root
        .delegate(
            vec!["record".to_string()],
            vec![],
            Some(Arc::new(RecordPolicy)),
        )
        .map_err(|error| error.to_string())?;
    let token = CancellationToken::new();
    token.cancel();
    let error = canceled
        .run(
            Arc::new(FixtureModel {
                tool_name: "record".to_string(),
                arguments: args("safe"),
                completion: "unexpected".to_string(),
            }),
            &cancel_tools,
            "record after cancel",
            Some(token),
            Vec::new(),
        )
        .expect_err("canceled child must fail");
    if error.code != "AGENT_CANCELLED" {
        return Err(format!("unexpected cancellation error: {}", error.code));
    }
    if cancel_calls.load(Ordering::SeqCst) != 0 {
        return Err("canceled child produced an effect".to_string());
    }
    canceled.release();

    let edit_calls = Arc::new(AtomicUsize::new(0));
    let mut edit_tools = Registry::new();
    edit_tools.register(Arc::new(RecordTool {
        calls: edit_calls.clone(),
    }));
    let edit_root = Governor::new(root_authority(&["record"], &["record"], 1, 1, 1));
    let edited = edit_root
        .delegate(
            vec!["record".to_string()],
            vec![],
            Some(Arc::new(RecordPolicy)),
        )
        .map_err(|error| error.to_string())?;
    let error = edited
        .run(
            Arc::new(FixtureModel {
                tool_name: "record".to_string(),
                arguments: args("safe"),
                completion: "unexpected".to_string(),
            }),
            &edit_tools,
            "record safely",
            None,
            vec![Box::new(EditMiddleware)],
        )
        .expect_err("edited child arguments must be reauthorized");
    if error.code != "AGENT_POLICY_DENIED" {
        return Err(format!("unexpected policy error: {}", error.code));
    }
    if edit_calls.load(Ordering::SeqCst) != 0 {
        return Err("edited child arguments produced an effect".to_string());
    }
    edited.release();

    Ok(())
}

fn main() {
    match run_checks() {
        Ok(()) => println!("governance: delegation checks passed (6)"),
        Err(error) => {
            eprintln!("governance: {error}");
            std::process::exit(1);
        }
    }
}
