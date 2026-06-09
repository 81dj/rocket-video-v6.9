import os
import uuid
import asyncio
import re
import subprocess
import json
from typing import List, Optional
from fastapi import FastAPI, BackgroundTasks, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from pydantic import BaseModel
import aiofiles

app = FastAPI()

# Storage paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = "/home/team/shared/output"
TEMP_DIR = os.path.join(BASE_DIR, "temp")

os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(TEMP_DIR, exist_ok=True)

# Project state (in-memory for now, could be moved to team-db)
projects = {}
active_connections = {}

class ProjectCreate(BaseModel):
    transcript: str
    aspect_ratio: str = "16:9"

class ProjectStatus(BaseModel):
    id: str
    status: str
    progress: int
    video_url: Optional[str] = None

# Segmentation logic
TARGET_DURATION = 8
WORDS_PER_SECOND = 2.5

def build_visual_prompt(text):
    return f"cinematic, photorealistic, dramatic lighting, storytelling scene about {text}"

def split_transcript_to_segments(text):
    sentences = re.split(r'(?<=[.!?])\s+', text)
    segments = []
    current_segment = []
    current_words = 0
    max_words = int(TARGET_DURATION * WORDS_PER_SECOND)

    for sentence in sentences:
        sentence = sentence.strip()
        if not sentence:
            continue
        sentence_words = len(sentence.split())

        if current_words + sentence_words > max_words and current_segment:
            combined = " ".join(current_segment)
            segments.append({
                "text": combined,
                "duration": TARGET_DURATION,
                "prompt": build_visual_prompt(combined),
            })
            current_segment = []
            current_words = 0

        current_segment.append(sentence)
        current_words += sentence_words

    if current_segment:
        combined = " ".join(current_segment)
        segments.append({
            "text": combined,
            "duration": TARGET_DURATION,
            "prompt": build_visual_prompt(combined),
        })

    return segments

# Video generation logic
# Helper for team-db
def run_team_db(query):
    try:
        result = subprocess.run(['team-db', query], capture_output=True, text=True, check=True)
        return json.loads(result.stdout)
    except Exception as e:
        print(f"team-db error: {e}")
        return None

async def update_status(project_id, status, progress, video_url=None):
    # Update in-memory for immediate WS broadcast
    if project_id in projects:
        projects[project_id].update({
            "status": status,
            "progress": progress,
            "video_url": video_url
        })
    
    # Persist to team-db
    if video_url:
        run_team_db(f"UPDATE projects SET status = '{status}', progress = {progress}, video_url = '{video_url}' WHERE id = '{project_id}'")
    else:
        run_team_db(f"UPDATE projects SET status = '{status}', progress = {progress} WHERE id = '{project_id}'")
    
    # Broadcast to WebSocket
    if project_id in active_connections:
        dead_connections = []
        for ws in active_connections[project_id]:
            try:
                await ws.send_text(json.dumps({
                    "id": project_id,
                    "status": status,
                    "progress": progress,
                    "video_url": video_url
                }))
            except:
                dead_connections.append(ws)
        for dc in dead_connections:
            active_connections[project_id].remove(dc)

async def generate_video_pipeline(project_id: str, transcript: str, aspect_ratio: str):
    try:
        project_temp_dir = os.path.join(TEMP_DIR, project_id)
        os.makedirs(project_temp_dir, exist_ok=True)

        await update_status(project_id, "processing", 5)

        # 1. Segmenting
        await update_status(project_id, "segmenting", 10)
        segments = split_transcript_to_segments(transcript)
        
        # 2. Generating visuals
        await update_status(project_id, "generating", 20)
        segment_files = []
        effects = ["zoom_in", "zoom_out", "pan_left", "pan_right", "parallax"]
        
        if aspect_ratio == "9:16":
            width, height = 720, 1280
        else:
            width, height = 1280, 720

        for i, segment in enumerate(segments):
            effect = effects[i % len(effects)]
            output_path = os.path.join(project_temp_dir, f"segment_{i}.mp4")
            
            # Mock image generation: Create a solid color image with text
            img_path = os.path.join(project_temp_dir, f"img_{i}.png")
            color = ["red", "green", "blue", "yellow", "purple", "orange"][i % 6]
            
            # Create colored background
            subprocess.run([
                'ffmpeg', '-f', 'lavfi', '-i', f'color=c={color}:s={width}x{height}',
                '-frames:v', '1', img_path, '-y'
            ], check=True, capture_output=True)

            # Add text to image (optional but good for debugging)
            # subprocess.run([
            #     'ffmpeg', '-i', img_path, '-vf', f"drawtext=text='{segment['text'][:30]}...':fontcolor=white:fontsize=40:x=(w-text_w)/2:y=(h-text_h)/2",
            #     os.path.join(project_temp_dir, f"img_text_{i}.png"), '-y'
            # ], check=True, capture_output=True)
            # img_path = os.path.join(project_temp_dir, f"img_text_{i}.png")

            effect_params = {
                "zoom_in": f"zoompan=z='min(zoom+0.0015,1.5)':d=200:s={width}x{height}",
                "zoom_out": f"zoompan=z='1.5-0.0015*on':d=200:s={width}x{height}",
                "pan_left": f"zoompan=z=1.1:x='iw/2-(iw/zoom/2)+10*on':y=ih/2:d=200:s={width}x{height}",
                "pan_right": f"zoompan=z=1.1:x='iw/2-(iw/zoom/2)-10*on':y=ih/2:d=200:s={width}x{height}",
                "parallax": f"zoompan=z='1.2+0.1*sin(2*PI*on/100)':d=200:s={width}x{height}",
            }
            vf = effect_params.get(effect, effect_params["zoom_in"])

            cmd = [
                'ffmpeg', '-loop', '1', '-i', img_path,
                '-vf', vf,
                '-c:v', 'libx264', '-t', '8', '-pix_fmt', 'yuv420p',
                output_path, '-y'
            ]
            subprocess.run(cmd, check=True, capture_output=True)
            segment_files.append(output_path)
            
            progress = 20 + int((i + 1) / len(segments) * 50)
            await update_status(project_id, "generating", progress)

        # 3. Composing
        await update_status(project_id, "composing", 80)
        
        final_video_path = os.path.join(OUTPUT_DIR, f"{project_id}.mp4")
        
        if len(segment_files) == 1:
            subprocess.run(['cp', segment_files[0], final_video_path], check=True)
        else:
            # Build xfade complex filter
            # [0:v][1:v]xfade=transition=fade:duration=0.5:offset=7.5[v1]; [v1][2:v]xfade=transition=fade:duration=0.5:offset=15.0[v2]...
            filter_complex = ""
            last_label = "[0:v]"
            offset = 7.5
            for i in range(1, len(segment_files)):
                next_label = f"[v{i}]"
                filter_complex += f"{last_label}[{i}:v]xfade=transition=fade:duration=0.5:offset={offset}{next_label}"
                if i < len(segment_files) - 1:
                    filter_complex += "; "
                    last_label = next_label
                offset += 7.5
            
            cmd = ['ffmpeg']
            for f in segment_files:
                cmd.extend(['-i', f])
            cmd.extend(['-filter_complex', filter_complex, '-map', f"[v{len(segment_files)-1}]", '-c:v', 'libx264', '-pix_fmt', 'yuv420p', final_video_path, '-y'])
            
            subprocess.run(cmd, check=True, capture_output=True)
        
        await update_status(project_id, "completed", 100, video_url=f"/api/projects/{project_id}/video")

        # Cleanup temp files
        subprocess.run(['rm', '-rf', project_temp_dir])

    except Exception as e:
        print(f"Error generating video: {project_id} - {str(e)}")
        await update_status(project_id, "failed", 0)

@app.post("/api/projects", response_model=ProjectStatus)
async def create_project(project_in: ProjectCreate, background_tasks: BackgroundTasks):
    project_id = str(uuid.uuid4())
    projects[project_id] = {
        "id": project_id,
        "status": "pending",
        "progress": 0,
        "transcript": project_in.transcript,
        "aspect_ratio": project_in.aspect_ratio,
        "video_url": None
    }
    
    # Persist to team-db
    # Escaping single quotes for SQL
    escaped_transcript = project_in.transcript.replace("'", "''")
    run_team_db(f"INSERT INTO projects (id, transcript, aspect_ratio, status, progress) VALUES ('{project_id}', '{escaped_transcript}', '{project_in.aspect_ratio}', 'pending', 0)")
    
    background_tasks.add_task(generate_video_pipeline, project_id, project_in.transcript, project_in.aspect_ratio)
    return projects[project_id]

@app.get("/api/projects/{project_id}/status", response_model=ProjectStatus)
async def get_project_status(project_id: str):
    if project_id in projects:
        return projects[project_id]
    
    # Fallback to team-db
    db_result = run_team_db(f"SELECT * FROM projects WHERE id = '{project_id}'")
    if db_result and len(db_result) > 0:
        # Map DB row to pydantic model
        row = db_result[0]
        return {
            "id": row['id'],
            "status": row['status'],
            "progress": row['progress'],
            "video_url": row['video_url']
        }
        
    raise HTTPException(status_code=404, detail="Project not found")

@app.get("/api/projects/{project_id}/video")
async def get_project_video(project_id: str):
    video_path = os.path.join(OUTPUT_DIR, f"{project_id}.mp4")
    if not os.path.exists(video_path):
        raise HTTPException(status_code=404, detail="Video not found")
    return FileResponse(video_path)

@app.websocket("/ws/projects/{project_id}")
async def websocket_endpoint(websocket: WebSocket, project_id: str):
    await websocket.accept()
    if project_id not in active_connections:
        active_connections[project_id] = []
    active_connections[project_id].append(websocket)
    try:
        if project_id in projects:
            await websocket.send_text(json.dumps(projects[project_id]))
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        active_connections[project_id].remove(websocket)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
