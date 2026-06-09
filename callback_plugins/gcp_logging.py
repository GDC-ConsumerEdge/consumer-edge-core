import os
import subprocess
import json
import getpass
import socket
from ansible.plugins.callback import CallbackBase

class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'gcp_logging'

    def __init__(self):
        super(CallbackModule, self).__init__()
        self.project_id = os.environ.get('GOOGLE_PROJECT_ID') or os.environ.get('PROJECT_ID')
        self.enabled = False
        
        # 1. Customizable log name via environment variable (default: ansible-playbook-runs)
        self.log_name = os.environ.get('ANSIBLE_GCP_LOG_NAME', 'ansible-playbook-runs')
        
        # 2. Customizable labels via environment variable (e.g. env=prod,owner=ops)
        self.custom_labels = os.environ.get('ANSIBLE_GCP_LOG_LABELS', '')
        
        # 3. Customizable log level/verbosity (default: INFO)
        # Supported: NOTICE (playbook runs & failures), ERROR (failures only), INFO (all tasks)
        self.log_level = os.environ.get('ANSIBLE_GCP_LOG_LEVEL', 'INFO').upper()
        
        # Gather execution metadata
        self.username = getpass.getuser()
        self.hostname = socket.gethostname()
        self.playbook_name = "unknown"

        if self.project_id:
            try:
                subprocess.run(['gcloud', '--version'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                self.enabled = True
            except (subprocess.SubprocessError, FileNotFoundError):
                self._display.warning("gcp_logging: 'gcloud' command not found. GCP logging disabled.")
        else:
            self._display.warning("gcp_logging: GOOGLE_PROJECT_ID or PROJECT_ID environment variable not set. GCP logging disabled.")

    def log_to_gcp(self, message, severity='INFO', payload=None):
        if not self.enabled:
            return
        
        # Verbosity Filtering
        # ERROR level only allows ERROR / CRITICAL severities
        if self.log_level == 'ERROR' and severity not in ['ERROR', 'CRITICAL']:
            return
        # NOTICE level only allows NOTICE, WARNING, ERROR, CRITICAL
        if self.log_level == 'NOTICE' and severity == 'INFO':
            return
        
        try:
            # Build base JSON payload for structured logging
            log_payload = {
                "message": message,
                "operator": self.username,
                "source_host": self.hostname,
                "playbook": self.playbook_name
            }
            if payload:
                log_payload.update(payload)

            # Ensure the payload is cleanly serializable
            try:
                serialized_payload = json.dumps(log_payload)
            except TypeError:
                cleaned_payload = {}
                for k, v in log_payload.items():
                    try:
                        json.dumps(v)
                        cleaned_payload[k] = v
                    except TypeError:
                        cleaned_payload[k] = str(v)
                serialized_payload = json.dumps(cleaned_payload)

            cmd = [
                'gcloud', 'logging', 'write', 
                self.log_name, 
                serialized_payload, 
                '--payload-type=json', 
                f'--project={self.project_id}', 
                f'--severity={severity}'
            ]

            # Append custom labels if provided
            if self.custom_labels:
                cmd.append(f'--labels={self.custom_labels}')

            # Execute asynchronously in background to prevent blocking playbook speed
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as e:
            self._display.warning(f"gcp_logging: Failed to stream log to GCP: {str(e)}")

    def v2_playbook_on_start(self, playbook):
        self.playbook_name = os.path.basename(playbook._file_name)
        self.log_to_gcp(
            message=f"Playbook started: {self.playbook_name}",
            severity='NOTICE',
            payload={
                "event": "playbook_start"
            }
        )

    def v2_runner_on_ok(self, result):
        task_name = result._task.name
        host = result._host.name
        
        # Check if the task has no_log set to protect sensitive credentials (e.g. passwords/keys)
        if result._task.no_log:
            task_result = {"msg": "Result redacted because 'no_log: true' is set on the task."}
        else:
            task_result = result._result

        # Dynamically append display output (like message/stdout) to the main log text
        extra_info = ""
        if isinstance(task_result, dict):
            if 'msg' in task_result:
                extra_info = f" | msg: {task_result['msg']}"
            elif 'stdout' in task_result and task_result['stdout']:
                extra_info = f" | stdout: {task_result['stdout']}"

        self.log_to_gcp(
            message=f"Task OK: [{host}] - {task_name}{extra_info}",
            severity='INFO',
            payload={
                "event": "task_ok",
                "task_host": host,
                "task": task_name,
                "status": "OK",
                "task_result": task_result
            }
        )

    def v2_runner_on_failed(self, result, ignore_errors=False):
        task_name = result._task.name
        host = result._host.name
        
        # Check if the task has no_log set to protect sensitive credentials
        if result._task.no_log:
            task_result = {"msg": "Result redacted because 'no_log: true' is set on the task."}
        else:
            task_result = result._result

        # Identify failure error message
        msg = 'No error message'
        if isinstance(task_result, dict):
            msg = task_result.get('msg') or task_result.get('stderr') or task_result.get('stdout') or str(task_result)

        severity = 'WARNING' if ignore_errors else 'ERROR'
        self.log_to_gcp(
            message=f"Task FAILED: [{host}] - {task_name} - Error: {msg}",
            severity=severity,
            payload={
                "event": "task_failed",
                "task_host": host,
                "task": task_name,
                "status": "FAILED",
                "error": msg,
                "ignore_errors": ignore_errors,
                "task_result": task_result
            }
        )
