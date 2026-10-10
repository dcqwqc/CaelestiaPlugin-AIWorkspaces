#!/usr/bin/env python3
"""Best-effort Loom Working-card lifecycle for isolated AI sessions.

No shell, arbitrary filesystem, or browser operations are exposed to Loom;
only the local Loom MCP's task tools and loomctl's card removal are used.
Failure never prevents starting the underlying agent. Do not treat process
exit 0 as verified Done; a card the agent never reported on is removed
instead of being parked as "waiting" forever.
"""
from __future__ import annotations
import argparse, json, subprocess, sys
from pathlib import Path

MCP = Path.home() / ".local/share/caelestia/plugins/loom/loom_mcp.py"
CTL = MCP.with_name("loomctl.py")
PLACEHOLDER = "Agent started in its private workspace"
# Clean exit, or the user closing the terminal / pressing Ctrl+C.
QUIET_EXITS = {0, 129, 130, 143}

def call(name: str, args: dict) -> dict:
    if not MCP.is_file():return {"ok":False,"error":"loom-mcp-missing"}
    msg={"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":name,"arguments":args}}
    try:
        p=subprocess.run(["/usr/bin/python3","-u",str(MCP),"stdio"],
            input=json.dumps(msg)+"\n",capture_output=True,text=True,timeout=5)
        if p.returncode:return {"ok":False,"error":"loom-mcp-exit"}
        resp=next((json.loads(x) for x in p.stdout.splitlines() if x.startswith("{")),{})
        result=resp.get("result") or {}
        return result.get("structuredContent") or {"ok":False,"error":"no-result"}
    except (OSError,subprocess.TimeoutExpired,ValueError) as e:
        return {"ok":False,"error":type(e).__name__}

def remove(task_id: str) -> dict:
    if not CTL.is_file():return {"ok":False,"error":"loomctl-missing"}
    try:
        p=subprocess.run(["/usr/bin/python3",str(CTL),"work-delete-user",task_id],
            capture_output=True,text=True,timeout=5)
        return json.loads(p.stdout.strip() or "{}")
    except (OSError,subprocess.TimeoutExpired,ValueError) as e:
        return {"ok":False,"error":type(e).__name__}

def start(provider: str, session: str, existing: str | None) -> dict:
    if existing:
        q=call("loom_task_list",{})
        if q.get("ok") and any(z.get("id")==existing for z in q.get("tasks",[])):
            return {"ok":True,"task_id":existing,"reused":True}
    safe="".join(c for c in provider if c.isalnum() or c in " -_")[:24].strip() or "Agent"
    title=f"{safe.title()} · Session {session[-6:]}"
    r=call("loom_task_create",{"title":title,
        "summary":f"{PLACEHOLDER}. Verification pending.",
        "status":"working"})
    if r.get("ok") and isinstance(r.get("task"),dict):
        return {"ok":True,"task_id":r["task"].get("id"),"reused":False}
    return {"ok":False,"error":r.get("error","loom-unavailable")}

def finish(task_id:str, exit_code:int)->dict:
    r=call("loom_task_list",{})
    if not r.get("ok"):return r
    task=next((x for x in r.get("tasks",[]) if x.get("id")==task_id),None)
    if not task:return {"ok":False,"error":"loom-task-missing"}
    # Never overwrite an agent's verified Done / blocked or waiting state.
    if task.get("status") not in ("working",):
        return {"ok":True,"preserved_status":task.get("status")}
    previous_summary=str(task.get("summary") or "").strip()
    # The agent never reported anything: the card carries no information, so
    # leaving it as "awaiting verification" only clutters the board.
    untouched=not previous_summary or PLACEHOLDER in previous_summary
    if untouched and exit_code in QUIET_EXITS:
        result=remove(task_id)
        return {"ok":bool(result.get("ok")),"status":"removed"}
    status="waiting" if exit_code==0 else "blocked"
    summary=("Process exited; awaiting verification. " if exit_code==0
             else "Process failed; inspect before resuming. ")
    # Preserve meaningful model-provided status without displaying private command args.
    if not untouched:
        summary+=previous_summary[:120]
    summary=summary[:180].strip()
    result=call("loom_task_update",{"task_id":task_id,"status":status,"summary":summary})
    return {"ok":bool(result.get("ok")),"status":status}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest="action",required=True)
    a=sub.add_parser("start")
    a.add_argument("--provider",required=True);a.add_argument("--session",required=True)
    a.add_argument("--existing-id")
    b=sub.add_parser("finish")
    b.add_argument("--task-id",required=True);b.add_argument("--exit-code",type=int,required=True)
    args=parser.parse_args()
    result=start(args.provider,args.session,args.existing_id) if args.action=="start" else finish(args.task_id,args.exit_code)
    print(json.dumps(result,ensure_ascii=False))
    return 0 if result.get("ok") else 2
if __name__=="__main__":sys.exit(main())
