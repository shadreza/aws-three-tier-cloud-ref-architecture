"""Builds the architecture diagrams in this folder.

Run it after changing a diagram:

    python3 docs/diagrams/build.py

Each diagram is a function below. Boxes are placed by hand (x, y), so moving
one box usually means moving its arrows too.
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent

COLORS = {
    "compute": "#ED7100",
    "network": "#8C4FFF",
    "database": "#C925D1",
    "storage": "#7AA116",
    "integration": "#E7157B",
    "security": "#DD344C",
    "client": "#5A6877",
}

STYLE = """<style>
  text { font-family:"IBM Plex Sans",system-ui,-apple-system,"Segoe UI",Roboto,sans-serif; }
  .n { stroke-width:1.2; }
  .n.dash { stroke-dasharray:5 4; stroke-width:1.3; }
  .ab { font-family:"IBM Plex Mono",ui-monospace,SFMono-Regular,Menlo,monospace; font-size:8.5px; font-weight:600; fill:#fff; }
  .t { font-size:12px; font-weight:600; }
  .s { font-size:10.5px; }
  .gt { font-size:12px; font-weight:600; }
  .grp { stroke-width:1; }
  .region { fill:none; stroke:#00A4A6; stroke-width:1.4; stroke-dasharray:7 5; }
  .vpc { fill:none; stroke:#8C4FFF; stroke-width:1.4; }
  .pub { stroke:#7AA116; stroke-width:1; }
  .priv { stroke:#00A4A6; stroke-width:1; }
  .iso { stroke:#147EBA; stroke-width:1; }
  .gl { font-size:12px; font-weight:600; }
  text.reg { fill:#00A4A6; } text.vpcl { fill:#8C4FFF; }
  .sl { font-family:"IBM Plex Mono",ui-monospace,SFMono-Regular,Menlo,monospace; font-size:10.5px; letter-spacing:.06em; }
  text.publ { fill:#7AA116; } text.privl { fill:#00A4A6; } text.isol { fill:#147EBA; }
  .ar { fill:none; stroke-width:1.4; }
  .ar.thin { stroke-dasharray:3 3; }
  .al { font-size:10.5px; paint-order:stroke; stroke-width:3px; stroke-linejoin:round; }
  .lg { font-size:11px; }
  svg { color:#5A6877; }
  .bg { fill:#F3F6F8; }
  .n { fill:#FFFFFF; stroke:#C6D0D9; }
  .n.dash { stroke:#15202B; }
  .t, .gt { fill:#15202B; }
  .s, .sl, .al, .lg { fill:#5A6877; }
  .al { stroke:#FFFFFF; }
  .grp { fill:#F7F9FB; stroke:#C6D0D9; }
  .pub { fill:rgba(122,161,22,.07); }
  .priv { fill:rgba(0,164,166,.06); }
  .iso { fill:rgba(20,126,186,.07); }
  .ar { stroke:#5A6877; }
  .mk { fill:#5A6877; }
  @media (prefers-color-scheme: dark) {
  svg { color:#95A3B1; }
  .bg { fill:#0E141A; }
  .n { fill:#161F28; stroke:#344352; }
  .n.dash { stroke:#E2E8EE; }
  .t, .gt { fill:#E2E8EE; }
  .s, .sl, .al, .lg { fill:#95A3B1; }
  .al { stroke:#161F28; }
  .grp { fill:#121A22; stroke:#344352; }
  .pub { fill:rgba(122,161,22,.10); }
  .priv { fill:rgba(0,164,166,.09); }
  .iso { fill:rgba(20,126,186,.12); }
  .ar { stroke:#95A3B1; }
  .mk { fill:#95A3B1; }
  }
</style>"""

DEFS = """<defs>
  <marker id="h" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path class="mk" d="M0,0 L10,5 L0,10 z"/>
  </marker>
</defs>"""


class Svg:
    def __init__(self, w, h, label):
        self.w, self.h, self.label = w, h, label
        self.parts = []

    def add(self, s):
        self.parts.append(s)

    def card(self, x, y, cat, abbr, title, sub, w=170, dash=False):
        cls = "n dash" if dash else "n"
        self.add(f'<rect class="{cls}" x="{x}" y="{y}" width="{w}" height="44" rx="6"/>')
        self.add(f'<rect x="{x+8}" y="{y+8}" width="28" height="28" rx="4" fill="{COLORS[cat]}"/>')
        self.add(f'<text class="ab" x="{x+22}" y="{y+25.5}" text-anchor="middle">{abbr}</text>')
        self.add(f'<text class="t" x="{x+44}" y="{y+19}">{title}</text>')
        self.add(f'<text class="s" x="{x+44}" y="{y+34}">{sub}</text>')

    def rect(self, cls, x, y, w, h, rx=8):
        self.add(f'<rect class="{cls}" x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}"/>')

    def text(self, cls, x, y, s, anchor="start"):
        self.add(f'<text class="{cls}" x="{x}" y="{y}" text-anchor="{anchor}">{s}</text>')

    def arrow(self, d, thin=False, both=False):
        cls = "ar thin" if thin else "ar"
        start = ' marker-start="url(#h)"' if both else ""
        self.add(f'<path class="{cls}" d="{d}" marker-end="url(#h)"{start}/>')

    def line(self, d, thin=False):
        """A connector with no arrow head, for trunks that branch into arrows."""
        cls = "ar thin" if thin else "ar"
        self.add(f'<path class="{cls}" d="{d}"/>')

    def legend(self, y, items):
        x = 20
        for kind, value, label in items:
            if kind == "cat":
                self.add(f'<rect x="{x}" y="{y-10}" width="12" height="12" rx="3" fill="{COLORS[value]}"/>')
                x += 18
            elif kind == "dash":
                self.add(f'<rect class="n dash" x="{x}" y="{y-11}" width="22" height="14" rx="3"/>')
                x += 28
            elif kind == "line":
                self.add(f'<path class="ar{" thin" if value else ""}" d="M{x},{y-4} h26"/>')
                x += 32
            self.add(f'<text class="lg" x="{x}" y="{y}">{label}</text>')
            x += 7 * len(label) + 22

    def save(self, name):
        body = "\n".join(self.parts)
        svg = (
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" '
            f'width="{self.w}" height="{self.h}" role="img" aria-label="{self.label}">\n'
            f"{STYLE}\n{DEFS}\n"
            f'<rect class="bg" x="0" y="0" width="{self.w}" height="{self.h}" rx="10"/>\n'
            f"{body}\n</svg>\n"
        )
        (OUT / name).write_text(svg)


def local_architecture():
    s = Svg(1110, 580, "The app on your laptop: the browser and terminal talk to web, api and mysql containers; "
                       "the scheduler checks websites on the internet and writes results and reports.")

    s.rect("region", 12, 30, 900, 488, rx=10)
    s.text("gl reg", 26, 50, "Your laptop")
    s.rect("vpc", 200, 62, 700, 440)
    s.text("gl vpcl", 214, 81, "Docker Compose · network uptime")

    s.rect("pub", 214, 92, 180, 398, rx=6)
    s.text("sl publ", 226, 110, "TIER 1 · WEB")
    s.rect("priv", 410, 92, 250, 398, rx=6)
    s.text("sl privl", 422, 110, "TIER 2 · APP")
    s.rect("iso", 675, 92, 212, 398, rx=6)
    s.text("sl isol", 687, 110, "TIER 3 · DATA")
    s.text("sl", 935, 110, "INTERNET")

    # cards
    s.card(24, 200, "client", "WWW", "Browser", "you, on :5173", w=140)
    s.card(24, 330, "client", "SH", "Terminal", "make, curl", w=140)
    s.card(219, 200, "compute", "WEB", "web", "React + Vite · :5173")
    s.card(450, 130, "compute", "MIG", "migrate", "runs once, then exits", dash=True)
    s.card(450, 200, "compute", "API", "api", "Go · :8080")
    s.card(450, 330, "integration", "SCH", "scheduler", "check 1 min · rollup 5 min")
    s.card(695, 200, "database", "DB", "mysql", "MySQL 8.4 · :3306")
    s.card(695, 260, "storage", "VOL", "mysql-data", "volume · the tables")
    s.card(695, 330, "storage", "VOL", "reports", "volume · daily CSV files")
    s.card(935, 330, "network", "NET", "Websites", "example.com, ...", w=160)

    # arrows
    s.arrow("M164,222 H219")
    s.text("al", 166, 194, "localhost:5173")
    s.arrow("M389,222 H450")
    s.text("al", 419, 214, "/api/*", anchor="middle")
    s.arrow("M620,222 H695")
    s.text("al", 657, 214, "SQL", anchor="middle")
    s.arrow("M620,152 H780 V200", thin=True)
    s.text("al", 640, 145, "create tables")
    s.arrow("M164,352 H425 V234 H450", thin=True)
    s.text("al", 300, 344, "curl localhost:8080", anchor="middle")
    s.arrow("M620,340 H655 V238 H695")
    s.text("al", 650, 292, "save results", anchor="end")
    s.arrow("M620,356 H695")
    s.text("al", 657, 372, "write CSV", anchor="middle")
    s.arrow("M535,374 V470 H1015 V374")
    s.text("al", 800, 462, "HTTP check, every minute", anchor="middle")

    s.legend(552, [
        ("cat", "compute", "Container"),
        ("cat", "integration", "Scheduled jobs"),
        ("cat", "database", "Database"),
        ("cat", "storage", "Volume"),
        ("dash", None, "Runs once, then stops"),
        ("line", False, "Request / data"),
        ("line", True, "Setup / manual"),
    ])
    s.save("local-architecture.svg")


def aws_architecture():
    s = Svg(1320, 740, "Target AWS architecture in Tokyo: users reach CloudFront with WAF, which serves web files "
                       "from S3 and forwards /api through a VPC origin to an internal load balancer in private "
                       "subnets. ECS Fargate tasks in private subnets use RDS MySQL in isolated subnets and reach "
                       "the internet through a NAT gateway in the public subnets.")

    s.text("sl", 20, 116, "INTERNET")
    s.text("sl", 160, 116, "EDGE · GLOBAL")
    s.rect("region", 340, 40, 965, 660, rx=10)
    s.text("gl reg", 355, 60, "AWS Region · ap-northeast-1 (Tokyo)")
    s.rect("vpc", 355, 70, 660, 610)
    s.text("gl vpcl", 369, 89, "VPC 10.20.0.0/16 · 2 Availability Zones")
    s.rect("pub", 370, 98, 190, 570, rx=6)
    s.text("sl publ", 382, 116, "PUBLIC SUBNETS")
    s.rect("priv", 575, 98, 240, 570, rx=6)
    s.text("sl privl", 587, 116, "PRIVATE APP SUBNETS")
    s.rect("iso", 830, 98, 170, 570, rx=6)
    s.text("sl isol", 842, 116, "ISOLATED DATA")
    s.text("sl", 1060, 116, "REGIONAL SERVICES")

    s.rect("grp", 585, 290, 220, 360)
    s.text("gt", 597, 309, "ECS cluster · Fargate ARM")

    # internet + edge
    s.card(20, 300, "client", "WWW", "Users", "browser", w=110)
    s.card(20, 520, "network", "NET", "Websites", "example.com", w=110)
    s.card(160, 160, "network", "R53", "Route 53", "optional domain", w=160)
    s.card(160, 300, "network", "CF", "CloudFront", "HTTPS · CDN", w=160)
    s.card(160, 380, "security", "WAF", "WAF", "rules on CloudFront", w=160)
    s.card(160, 460, "security", "ACM", "ACM", "TLS certificates", w=160)

    # vpc
    s.card(380, 520, "network", "NAT", "NAT gateway", "outbound only")
    s.card(600, 230, "network", "ALB", "Load balancer", "internal · :80", w=190)
    s.card(600, 330, "compute", "ECS", "api service", "migrate first · 2+ tasks", w=190)
    s.card(600, 420, "compute", "ECS", "check task", "every minute", w=190, dash=True)
    s.card(600, 480, "compute", "ECS", "rollup task", "every hour", w=190, dash=True)
    s.card(835, 330, "database", "RDS", "RDS MySQL", "Multi-AZ in prod", w=160)

    # regional
    s.card(1060, 160, "storage", "S3", "S3 · web", "React build files")
    s.card(1060, 230, "compute", "ECR", "ECR", "container images")
    s.card(1060, 300, "security", "SM", "Secrets Manager", "password, admin token")
    s.card(1060, 430, "integration", "EB", "EventBridge", "Scheduler")
    s.card(1060, 520, "storage", "S3", "S3 · reports", "daily CSV files")
    s.card(1060, 600, "integration", "CW", "CloudWatch", "logs, metrics, alarms")

    # arrows
    s.arrow("M75,300 V182 H160", thin=True)
    s.text("al", 80, 240, "DNS lookup")
    s.arrow("M130,322 H160")
    s.arrow("M320,310 H332 V22 H1145 V160")
    s.text("al", 740, 16, "/  web files", anchor="middle")
    s.arrow("M320,332 H350 V252 H600")
    s.text("al", 465, 244, "/api/* · VPC origin", anchor="middle")
    s.arrow("M775,274 V330")
    s.text("al", 768, 322, ":8080", anchor="end")
    s.arrow("M790,352 H835")
    s.text("al", 812, 344, "3306", anchor="middle")
    s.arrow("M790,436 H900 V374")
    s.text("al", 908, 410, "save results")
    s.arrow("M1060,452 H790")
    s.text("al", 990, 446, "starts on schedule", anchor="middle")
    s.arrow("M1060,466 H1040 V510 H790", thin=True)
    s.arrow("M695,524 V542 H1060")
    s.text("al", 960, 536, "CSV", anchor="middle")
    s.arrow("M600,442 H566 V542 H550")
    s.text("al", 540, 510, "internet calls", anchor="end")
    s.arrow("M380,542 H130")
    s.text("al", 255, 534, "through the internet gateway", anchor="middle")
    s.arrow("M805,300 H1030 V252 H1060", thin=True)
    s.text("al", 918, 294, "pull image, read secrets, send logs", anchor="middle")

    s.legend(726, [
        ("cat", "network", "Networking"),
        ("cat", "compute", "Compute"),
        ("cat", "database", "Database"),
        ("cat", "storage", "Storage"),
        ("cat", "security", "Security"),
        ("cat", "integration", "Integration / monitoring"),
        ("dash", None, "Task that runs, then stops"),
        ("line", False, "Request / data"),
        ("line", True, "Control / lookup"),
    ])
    s.save("aws-target-architecture.svg")


def aws_network():
    s = Svg(1240, 752, "Step 02 network in Tokyo: a VPC with public, private and isolated subnets in two "
                       "Availability Zones. The public subnets hold only the NAT gateway. The internal load "
                       "balancer and the ECS tasks are private, RDS is isolated with no way out.")

    s.card(455, 14, "client", "WWW", "Internet", "users, checked websites")
    s.rect("region", 20, 80, 1200, 635, rx=10)
    s.text("gl reg", 34, 100, "AWS Region · ap-northeast-1 (Tokyo)")
    s.rect("vpc", 40, 130, 960, 570)
    s.text("gl vpcl", 54, 124, "VPC · 10.20.0.0/16 (dev)")
    s.card(455, 108, "network", "IGW", "Internet gateway", "the door to the internet")

    # Zone a has its labels on the left, zone c on the right, so the arrows
    # in the middle of the picture never cross text.
    for n, (x, az) in enumerate([(60, "ap-northeast-1a"), (530, "ap-northeast-1c")]):
        bx = x + 12
        lx, anchor = (bx + 12, "start") if n == 0 else (bx + 414, "end")
        s.rect("grp", x, 172, 450, 512)
        s.text("gt", x + 12 if n == 0 else x + 438, 191, f"Availability Zone {az}", anchor)
        s.rect("pub", bx, 202, 426, 114, rx=6)
        s.text("sl publ", lx, 220, f"PUBLIC · 10.20.{n}.0/24", anchor)
        s.text("s", bx + 414 if n == 0 else bx + 12, 304, "route: 0.0.0.0/0 to internet gateway",
               "end" if n == 0 else "start")
        s.rect("priv", bx, 330, 426, 200, rx=6)
        s.text("sl privl", lx, 348, f"PRIVATE · 10.20.{10 + n}.0/24", anchor)
        s.text("s", lx, 518, "route: 0.0.0.0/0 to a NAT gateway", anchor)
        s.rect("iso", bx, 544, 426, 126, rx=6)
        s.text("sl isol", lx, 562, f"ISOLATED · 10.20.{20 + n}.0/24", anchor)
        s.text("s", lx, 658, "route: only inside the VPC, no way out", anchor)

    # zone a
    s.card(110, 236, "network", "NAT", "NAT gateway", "Elastic IP · outbound only")
    s.card(300, 364, "network", "ALB", "Load balancer", "internal · step 04", w=190)
    s.card(300, 436, "compute", "ECS", "ECS tasks", "api, check, rollup · step 04", w=190)
    s.card(300, 580, "database", "RDS", "RDS MySQL", "primary · step 03")

    # zone c
    s.card(780, 236, "network", "NAT", "NAT gateway", "prod only (per_az)", w=160)
    s.card(560, 364, "network", "ALB", "Load balancer", "internal · step 04", w=190)
    s.card(560, 436, "compute", "ECS", "ECS tasks", "api, check, rollup · step 04", w=190)
    s.card(780, 436, "network", "VPCE", "S3 endpoint", "gateway · free", w=160)
    s.card(655, 580, "database", "RDS", "RDS standby", "prod only (Multi-AZ)")

    s.card(1030, 436, "storage", "S3", "Amazon S3", "image layers, reports", w=175)

    # internet <-> internet gateway
    s.arrow("M540,58 V108", both=True)
    # NAT gateways -> internet gateway
    s.arrow("M110,258 H50 V144 H455")
    s.arrow("M940,258 H990 V144 H625", thin=True)
    # load balancer -> tasks
    s.arrow("M395,408 V436")
    s.arrow("M655,408 V436")
    # tasks -> NAT gateway
    s.arrow("M300,458 H270 V280")
    s.text("al", 262, 424, "outbound calls", anchor="end")
    s.arrow("M750,446 H765 V324 H860 V280", thin=True)
    # tasks -> S3 endpoint -> S3
    s.arrow("M750,466 H780")
    s.arrow("M940,458 H1030")
    s.text("al", 985, 450, "no NAT fee", anchor="middle")
    # tasks -> database
    s.arrow("M395,480 V580")
    s.text("al", 403, 572, "3306")
    s.arrow("M740,480 V580")
    s.text("al", 732, 572, "3306", anchor="end")
    s.arrow("M470,602 H655", thin=True, both=True)
    s.text("al", 562, 594, "copy to standby", anchor="middle")

    s.legend(740, [
        ("cat", "network", "Networking"),
        ("cat", "compute", "Compute (step 04)"),
        ("cat", "database", "Database (step 03)"),
        ("cat", "storage", "Storage"),
        ("line", False, "Traffic"),
        ("line", True, "Only in prod"),
    ])
    s.save("aws-network.svg")

def step03_data():
    s = Svg(1380, 640, "Step 03 data layer: RDS MySQL in the isolated subnets with TLS required, a debug host "
                       "reached through an Instance Connect Endpoint, secrets in Secrets Manager and reports in S3.")
    s.card(20, 170, "client", "SH", "You", "laptop · SSH via EICE", w=160)
    s.card(20, 390, "client", "TF", "Terraform", "ephemeral password", w=160)

    s.rect("region", 210, 40, 1150, 560, rx=10)
    s.text("gl reg", 224, 60, "AWS Region · ap-northeast-1 (Tokyo)")
    s.rect("vpc", 230, 80, 640, 500)
    s.text("gl vpcl", 244, 99, "VPC · 10.20.0.0/16 (dev)")
    s.rect("priv", 250, 110, 600, 140, rx=6)
    s.text("sl privl", 262, 128, "PRIVATE SUBNETS")
    s.rect("iso", 250, 270, 600, 290, rx=6)
    s.text("sl isol", 262, 288, "ISOLATED SUBNETS · NO ROUTE OUT")

    s.card(270, 160, "network", "EICE", "Connect endpoint", "Instance Connect · free", w=180)
    s.card(470, 160, "compute", "EC2", "debug host", "t4g.nano · optional", w=170)
    s.card(660, 160, "compute", "ECS", "app tasks", "steps 04 and 06", w=170)

    s.card(280, 330, "database", "RDS", "RDS MySQL 8.4", "primary · 1a", w=180)
    s.card(620, 420, "database", "RDS", "RDS standby", "1c · prod Multi-AZ only", w=210)
    s.text("s", 270, 480, "DB subnet group: the two isolated subnets")
    s.text("s", 270, 498, "parameter group: require_secure_transport = 1")
    s.text("s", 270, 516, "gp3, 20 GB, grows to 100 GB · encrypted")
    s.text("s", 270, 534, "backups at 02:00 JST · 1 day dev, 7 days prod")
    s.text("s", 270, 552, "the app checks RDS's certificate (DB_TLS_CA)")

    s.card(900, 120, "security", "SM", "uptime-dev/db", "password, host, port", w=210)
    s.card(900, 190, "security", "SM", "uptime-dev/admin-token", "ADMIN_TOKEN", w=210)
    s.card(900, 300, "storage", "S3", "reports bucket", "reports/*.csv · 400 days", w=210)
    s.card(900, 410, "integration", "CW", "CloudWatch Logs", "RDS error + slow query", w=210)

    s.arrow("M180,192 H270")
    s.text("al", 225, 184, "SSH", anchor="middle")
    s.arrow("M450,182 H470")
    s.arrow("M555,204 V318 H370 V330")
    s.text("al", 462, 312, "3306 · TLS", anchor="middle")
    s.arrow("M745,204 V340 H460")
    s.text("al", 752, 300, "3306 · TLS")
    s.arrow("M460,364 H560 V442 H620", thin=True, both=True)
    s.text("al", 566, 400, "copy (prod)")
    s.arrow("M830,176 H870 V142 H900", thin=True)
    s.text("al", 850, 170, "secrets", anchor="middle")
    s.arrow("M830,196 H880 V322 H900")
    s.text("al", 886, 290, "CSV", anchor="end")
    s.arrow("M180,412 H240 V352 H280", thin=True)
    s.text("al", 200, 440, "password_wo, never in state")

    s.legend(628, [
        ("cat", "database", "Database"),
        ("cat", "security", "Secrets"),
        ("cat", "storage", "Storage"),
        ("cat", "compute", "Compute"),
        ("cat", "network", "Networking"),
        ("line", False, "Traffic"),
        ("line", True, "Control / setup / prod only"),
    ])
    s.save("step-03-data.svg")


def step04_compute():
    s = Svg(1380, 720, "Step 04 compute: an internal load balancer and an ECS Fargate ARM cluster in the private "
                       "subnets. Each API task runs migrate first, then api. Check and rollup task definitions "
                       "wait for the scheduler. Images come from ECR, secrets from Secrets Manager.")
    s.card(20, 90, "client", "SH", "You or CI", "image-push, image-use", w=170)

    s.rect("region", 210, 40, 1150, 640, rx=10)
    s.text("gl reg", 224, 60, "AWS Region · ap-northeast-1 (Tokyo)")
    s.rect("vpc", 230, 80, 700, 580)
    s.text("gl vpcl", 244, 99, "VPC · 10.20.0.0/16 (dev)")
    s.rect("priv", 250, 110, 660, 420, rx=6)
    s.text("sl privl", 262, 128, "PRIVATE SUBNETS · BOTH ZONES")
    s.rect("iso", 250, 544, 660, 100, rx=6)
    s.text("sl isol", 262, 562, "ISOLATED SUBNETS")

    s.card(270, 160, "network", "ALB", "internal ALB", ":80 · health /api/health", w=190)
    s.card(270, 300, "compute", "EC2", "debug host", "curl the ALB (testing)", w=190)
    s.text("s", 270, 390, "execution role (used by ECS):")
    s.text("s", 270, 406, "pull image, read secrets, logs")
    s.text("s", 270, 430, "task roles (used by the app):")
    s.text("s", 270, 446, "api reads S3, jobs write S3")

    s.rect("grp", 490, 140, 380, 380)
    s.text("gt", 502, 508, "ECS cluster uptime-dev · Fargate ARM64")
    s.rect("grp", 510, 180, 350, 130)
    s.text("s", 522, 199, "api service · task uptime-dev-api")
    s.card(520, 215, "compute", "ECS", "migrate", "runs first, exits", w=160, dash=True)
    s.card(700, 215, "compute", "ECS", "api", ":8080 · after migrate", w=155)
    s.card(505, 350, "compute", "ECS", "check", "task definition · step 06", w=175, dash=True)
    s.card(505, 420, "compute", "ECS", "rollup", "task definition · step 06", w=175, dash=True)

    s.card(700, 580, "database", "RDS", "RDS MySQL", "from step 03", w=170)

    s.card(970, 110, "compute", "ECR", "ECR", "uptime-dev/backend · immutable", w=220)
    s.card(970, 180, "integration", "SSM", "image tag", "/uptime-dev/image-tag", w=220)
    s.card(970, 250, "security", "SM", "Secrets Manager", "DB_PASSWORD, ADMIN_TOKEN", w=220)
    s.card(970, 320, "storage", "S3", "reports bucket", "api reads, jobs write", w=220)
    s.card(970, 390, "integration", "CW", "CloudWatch Logs", "/ecs/uptime-dev/api, /jobs", w=220)
    s.card(970, 460, "integration", "AS", "Auto Scaling", "prod: 2 to 4 API tasks", w=220)

    s.arrow("M105,90 V26 H1080 V110")
    s.text("al", 640, 20, "docker push (arm64), then the tag goes to SSM", anchor="middle")
    s.arrow("M365,300 V204")
    s.text("al", 373, 260, "HTTP :80")
    s.arrow("M460,170 H778 V215")
    s.text("al", 620, 164, "forward to :8080", anchor="middle")
    s.arrow("M680,237 H700", thin=True)
    s.arrow("M778,259 V580")
    s.text("al", 786, 330, "3306 TLS")
    s.arrow("M592,464 V602 H700")
    s.text("al", 600, 590, "jobs: 3306")
    s.line("M870,300 H950", thin=True)
    s.line("M950,132 V412", thin=True)
    for y in (132, 272, 342, 412):
        s.arrow(f"M950,{y} H970", thin=True)
    s.text("al", 910, 292, "pull, read, log", anchor="middle")
    s.arrow("M1080,180 V154", thin=True)

    s.legend(708, [
        ("cat", "compute", "Compute"),
        ("cat", "network", "Networking"),
        ("cat", "database", "Database"),
        ("cat", "storage", "Storage"),
        ("cat", "security", "Security"),
        ("cat", "integration", "Config / logs"),
        ("dash", None, "Runs, then stops"),
        ("line", False, "Traffic"),
        ("line", True, "Control / lookup"),
    ])
    s.save("step-04-compute.svg")


def step05_edge():
    s = Svg(1380, 600, "Step 05 edge: users reach CloudFront, checked by WAF. The default behavior serves the "
                       "web app from a private S3 bucket through OAC; /api/* goes through a VPC origin to the "
                       "internal load balancer and the API tasks.")
    s.card(20, 250, "client", "WWW", "Users", "browser, anywhere", w=150)
    s.text("sl", 212, 116, "EDGE · GLOBAL")
    s.card(210, 160, "security", "WAF", "WAF (us-east-1)", "rate limit + 3 rule groups", w=210)
    s.card(210, 250, "network", "CF", "CloudFront", "HTTPS · PriceClass_200", w=210)
    s.card(210, 340, "compute", "FN", "SPA function", "no dot in path: /index.html", w=210)
    s.card(210, 430, "security", "ACM", "ACM + Route 53", "optional custom domain", w=210)

    s.rect("region", 460, 40, 900, 520, rx=10)
    s.text("gl reg", 474, 60, "AWS Region · ap-northeast-1 (Tokyo)")
    s.rect("vpc", 480, 80, 640, 460)
    s.text("gl vpcl", 494, 99, "VPC · 10.20.0.0/16 (dev)")
    s.rect("pub", 500, 110, 600, 70, rx=6)
    s.text("sl publ", 512, 128, "PUBLIC SUBNETS")
    s.text("s", 512, 160, "only the NAT gateway lives here")
    s.rect("priv", 500, 200, 600, 320, rx=6)
    s.text("sl privl", 512, 218, "PRIVATE SUBNETS")

    s.card(520, 250, "network", "ENI", "VPC origin", "CloudFront's interfaces", w=200)
    s.card(800, 250, "network", "ALB", "internal ALB", ":80 · no public IP", w=190)
    s.card(800, 380, "compute", "ECS", "API tasks", ":8080 · sg app", w=190)
    s.text("s", 520, 330, "sg alb allows :80 only from")
    s.text("s", 520, 346, "CloudFront-VPCOrigins-Service-SG")
    s.text("s", 520, 362, "(and the debug host)")

    s.card(1150, 250, "storage", "S3", "web bucket", "private · OAC only", w=190)

    s.arrow("M170,272 H210")
    s.arrow("M315,250 V204", thin=True, both=True)
    s.text("al", 323, 232, "every request")
    s.arrow("M315,294 V340", thin=True)
    s.text("al", 323, 322, "web requests only")
    s.arrow("M420,262 H440 V24 H1245 V250")
    s.text("al", 840, 18, "default behavior · cached · signed with OAC", anchor="middle")
    s.arrow("M420,282 H520")
    s.text("al", 470, 274, "/api/* · never cached", anchor="middle")
    s.arrow("M720,272 H800")
    s.text("al", 760, 264, ":80", anchor="middle")
    s.arrow("M895,294 V380")
    s.text("al", 903, 342, ":8080")

    s.legend(588, [
        ("cat", "network", "Networking"),
        ("cat", "security", "Security"),
        ("cat", "compute", "Compute"),
        ("cat", "storage", "Storage"),
        ("line", False, "Request"),
        ("line", True, "Check / rewrite"),
    ])
    s.save("step-05-edge.svg")


def step06_jobs():
    s = Svg(1560, 580, "Step 06 jobs: EventBridge Scheduler starts the check task every minute and the rollup "
                       "task every hour through ECS RunTask. Tasks run in the private subnets, reach websites "
                       "through the NAT gateway, and write to RDS and S3.")
    s.rect("region", 20, 40, 1340, 500, rx=10)
    s.text("gl reg", 34, 60, "AWS Region · ap-northeast-1 (Tokyo)")

    s.rect("grp", 40, 80, 270, 190)
    s.text("gt", 52, 99, "schedule group uptime-dev")
    s.card(55, 120, "integration", "EB", "check", "rate(1 minute) · 0 retries", w=240)
    s.card(55, 190, "integration", "EB", "rollup", "rate(1 hour) · 2 retries", w=240)
    s.card(55, 300, "security", "IAM", "scheduler role", "RunTask + PassRole only", w=240)
    s.card(55, 390, "storage", "S3", "reports bucket", "reports/YYYY-MM-DD.csv", w=240)
    s.card(55, 460, "integration", "CW", "CloudWatch Logs", "/ecs/uptime-dev/jobs", w=240)

    s.rect("vpc", 560, 80, 560, 440)
    s.text("gl vpcl", 574, 99, "VPC · 10.20.0.0/16 (dev)")
    s.rect("pub", 580, 110, 520, 80, rx=6)
    s.text("sl publ", 592, 128, "PUBLIC")
    s.rect("priv", 580, 205, 520, 205, rx=6)
    s.text("sl privl", 1088, 223, "PRIVATE · sg jobs", anchor="end")
    s.rect("iso", 580, 420, 520, 85, rx=6)
    s.text("sl isol", 1088, 438, "ISOLATED", anchor="end")

    s.card(620, 130, "network", "NAT", "NAT gateway", "fixed Elastic IP", w=180)
    s.card(600, 240, "compute", "ECS", "check task", "runs a few seconds", w=200, dash=True)
    s.card(600, 320, "compute", "ECS", "rollup task", "summaries + CSV", w=200, dash=True)
    s.text("s", 600, 386, "lock uptime-check: a run that starts while")
    s.text("s", 600, 401, "another is busy skips its turn")
    s.card(860, 445, "database", "RDS", "RDS MySQL", "results, summaries", w=200)
    s.card(1380, 130, "client", "WWW", "Websites", "checked every minute", w=160)

    # schedules -> tasks (ecs:RunTask)
    s.arrow("M295,142 H570 V272 H600")
    s.text("al", 430, 136, "ecs:RunTask", anchor="middle")
    s.arrow("M295,212 H545 V342 H600")
    s.text("al", 430, 206, "ecs:RunTask", anchor="middle")
    s.arrow("M175,300 V270", thin=True)
    s.text("al", 183, 290, "used by both schedules")
    # check -> NAT -> websites
    s.arrow("M700,240 V174")
    s.text("al", 708, 200, "HTTP(S) checks")
    s.arrow("M800,152 H1380")
    s.text("al", 1090, 144, "through the internet gateway", anchor="middle")
    # tasks -> RDS
    s.arrow("M800,262 H920 V445")
    s.arrow("M800,342 H900 V445")
    s.text("al", 928, 300, "3306")
    # rollup -> S3, logs
    s.line("M600,356 H530 V412")
    s.arrow("M530,412 H295")
    s.text("al", 410, 404, "CSV", anchor="middle")
    s.arrow("M530,412 V482 H295", thin=True)
    s.text("al", 410, 476, "logs (both tasks)", anchor="middle")

    s.legend(568, [
        ("cat", "integration", "Scheduler / logs"),
        ("cat", "compute", "Compute"),
        ("cat", "network", "Networking"),
        ("cat", "database", "Database"),
        ("cat", "storage", "Storage"),
        ("cat", "security", "IAM"),
        ("dash", None, "Runs, then stops"),
        ("line", False, "Traffic"),
        ("line", True, "Control / logs"),
    ])
    s.save("step-06-jobs.svg")


def step07_observability():
    s = Svg(1380, 640, "Step 07 observability: AWS metrics and metrics made from the app's JSON logs feed ten "
                       "alarms, which notify an SNS topic that emails you. A dashboard and saved Logs Insights "
                       "queries are for looking deeper.")
    s.text("sl", 40, 44, "WHAT PRODUCES DATA")
    rows = [
        ("network", "ALB", "load balancer", "5xx, latency, healthy hosts"),
        ("compute", "ECS", "ECS service", "CPU, memory"),
        ("database", "RDS", "RDS", "CPU, credits, free storage"),
        ("integration", "EB", "Scheduler", "TargetErrorCount"),
        ("security", "WAF", "WAF (us-east-1)", "on the dashboard, no alarm"),
        ("integration", "CW", "JSON app logs", "/ecs/uptime-dev/api, /jobs"),
    ]
    for i, (cat, abbr, title, sub) in enumerate(rows):
        s.card(40, 60 + i * 80, cat, abbr, title, sub, w=240)

    s.card(330, 460, "integration", "MF", "metric filters", "CheckRuns, MonitorsDown, Errors", w=230)

    s.rect("grp", 610, 50, 300, 440)
    s.text("gt", 622, 70, "10 alarms · Uptime/dev and AWS/*")
    alarms = ["api-5xx", "alb-5xx", "api-no-healthy-tasks", "api-slow (p95 over 1 s)", "db-cpu-high",
              "db-cpu-credits-low", "db-storage-low", "scheduler-errors",
              "checks-stopped (silence = alarm)", "app-errors"]
    for i, a in enumerate(alarms):
        s.text("s", 630, 100 + i * 36, a)

    s.card(960, 200, "integration", "SNS", "SNS topic", "uptime-dev-alerts", w=200)
    s.card(1190, 200, "client", "@", "You", "ALARM and OK emails", w=170)
    s.card(960, 370, "integration", "LI", "Logs Insights", "3 saved queries", w=200)
    s.card(960, 470, "integration", "DSH", "dashboard", "9 widgets, one screen", w=200)

    for i in range(4):
        y = 82 + i * 80
        s.arrow(f"M280,{y} H610")
    s.arrow("M280,482 H330")
    s.arrow("M560,482 H610")
    s.arrow("M910,222 H960")
    s.text("al", 935, 214, "notify", anchor="middle")
    s.arrow("M1160,222 H1190")
    s.arrow("M160,504 V600 H1190 V392 H1160", thin=True)
    s.text("al", 600, 594, "query the raw logs when an alarm fires", anchor="middle")
    s.arrow("M910,440 H935 V492 H960", thin=True)
    s.text("al", 918, 470, "graphs", anchor="end")

    s.legend(628, [
        ("cat", "integration", "CloudWatch / SNS"),
        ("cat", "network", "Networking"),
        ("cat", "compute", "Compute"),
        ("cat", "database", "Database"),
        ("cat", "security", "Security"),
        ("line", False, "Data / notification"),
        ("line", True, "Looking deeper"),
    ])
    s.save("step-07-observability.svg")


def step08_cicd():
    s = Svg(1380, 620, "Step 08 CI/CD: pull requests run ci.yml with no AWS access. A push to master builds the "
                       "image and web app once, then deploys them to dev, staging and prod. Each deploy job logs in "
                       "through GitHub OIDC and STS to a role that can only deploy.")
    s.rect("grp", 20, 40, 560, 540)
    s.text("gt", 32, 60, "GitHub · shadreza/aws-three-tier-cloud-ref-architecture")
    s.card(40, 90, "client", "PR", "pull request", "any branch", w=170)
    s.card(40, 300, "client", "GIT", "push to master", "after the PR merges", w=170)
    s.card(260, 90, "integration", "CI", "ci.yml", "tests, validate, ARM build · no AWS", w=290)
    s.card(260, 230, "integration", "BLD", "deploy.yml · build", "image + web once · artifacts", w=290)
    s.card(260, 330, "compute", "DEV", "environment dev", "if DEPLOY_DEV", w=290)
    s.card(260, 410, "compute", "STG", "environment staging", "if DEPLOY_STAGING", w=290)
    s.card(260, 490, "security", "PRD", "environment prod", "DEPLOY_PROD + required reviewers", w=290)

    s.rect("region", 620, 40, 740, 540, rx=10)
    s.text("gl reg", 634, 60, "AWS account · ap-northeast-1 (Tokyo)")
    s.card(640, 90, "security", "OIDC", "GitHub OIDC provider", "from bootstrap, one per account", w=230)
    s.card(640, 180, "security", "STS", "AWS STS", "credentials for 1 hour", w=230)
    s.card(640, 270, "security", "IAM", "uptime-dev-github-deploy", "trusts repo + environment dev", w=230)
    s.text("s", 640, 350, "one role per environment;")
    s.text("s", 640, 366, "it can deploy and nothing else")

    targets = [
        ("compute", "ECR", "ECR", "push uptime-dev/backend:TAG"),
        ("integration", "SSM", "image tag", "make image-use"),
        ("storage", "S3", "state bucket", "read dev/*, write compute"),
        ("compute", "ECS", "compute stack", "task definitions + service"),
        ("storage", "S3", "web bucket", "make web-upload"),
        ("network", "CF", "CloudFront", "invalidate /index.html"),
    ]
    for i, (cat, abbr, title, sub) in enumerate(targets):
        s.card(920, 90 + i * 75, cat, abbr, title, sub, w=240)

    s.arrow("M210,112 H260")
    s.arrow("M125,300 V190 H405 V134", thin=True)
    s.arrow("M210,322 H235 V252 H260")
    s.arrow("M405,274 V330")
    s.arrow("M405,374 V410")
    s.arrow("M405,454 V490")
    s.line("M550,352 H600")
    s.line("M550,432 H600")
    s.line("M550,512 H600 V202")
    s.arrow("M600,202 H640")
    s.text("al", 595, 196, "token", anchor="end")
    s.arrow("M755,134 V180", thin=True)
    s.text("al", 763, 162, "checks the signature")
    s.arrow("M755,224 V270")
    s.line("M870,292 H895")
    s.line("M895,112 V487")
    for i in range(6):
        s.arrow(f"M895,{112 + i * 75} H920")

    s.legend(608, [
        ("cat", "integration", "Workflows / config"),
        ("cat", "compute", "Deploy targets"),
        ("cat", "security", "Identity"),
        ("cat", "storage", "Storage"),
        ("line", False, "Flow"),
        ("line", True, "Trust check"),
    ])
    s.save("step-08-cicd.svg")


def step09_environments():
    s = Svg(1380, 560, "Step 09 environments: one bootstrap per account (state bucket, budget, GitHub OIDC), "
                       "and three environments made from the same code with different values: dev, staging "
                       "and prod, each with its own VPC range and state files.")
    s.rect("region", 20, 40, 1340, 480, rx=10)
    s.text("gl reg", 34, 60, "AWS account · ap-northeast-1 (Tokyo)")

    s.rect("grp", 40, 96, 300, 400)
    s.text("gt", 52, 115, "once per account · bootstrap")
    s.card(55, 135, "storage", "S3", "uptime-tfstate-ACCOUNT", "one key per env and stack", w=270)
    s.card(55, 215, "integration", "BUD", "monthly budget", "email at 50, 80, 100%", w=270)
    s.card(55, 295, "security", "OIDC", "GitHub OIDC provider", "used by the cicd roles", w=270)
    s.text("s", 55, 380, "prod can live in its own AWS account,")
    s.text("s", 55, 396, "with its own bootstrap and bucket")

    envs = [
        (370, "uptime-dev · 10.20.0.0/16", "1 NAT gateway", "db.t4g.micro, single-AZ", "API: 1 task, 0.25 vCPU", "about $120 / month"),
        (690, "uptime-staging · 10.30.0.0/16", "1 NAT gateway", "db.t4g.micro, single-AZ", "API: 1 task, 0.25 vCPU", "about $120 / month"),
        (1010, "uptime-prod · 10.40.0.0/16", "2 NAT gateways (per_az)", "db.t4g.small, Multi-AZ", "API: 2 to 4 tasks, 0.5 vCPU", "about $253 / month"),
    ]
    for x, label, nat, db, api, cost in envs:
        w = 330 if x == 1010 else 300
        s.rect("vpc", x, 96, w, 400)
        s.text("gl vpcl", x + 14, 115, label)
        s.card(x + 15, 140, "network", "NAT", "network", nat, w=w - 30)
        s.card(x + 15, 210, "database", "RDS", "database", db, w=w - 30)
        s.card(x + 15, 280, "compute", "ECS", "compute", api, w=w - 30)
        s.card(x + 15, 350, "network", "CF", "edge", "own CloudFront + WAF", w=w - 30)
        env = label.split(" ")[0].replace("uptime-", "")
        s.text("s", x + 15, 430, f"state: {env}/&lt;stack&gt;.tfstate")
        s.text("s", x + 15, 448, f"values: terraform/envs/{env}/")
        s.text("t", x + 15, 476, cost)

    s.line("M300,135 V80 H1175", thin=True)
    for x in (520, 840, 1175):
        s.arrow(f"M{x},80 V96", thin=True)
    s.text("al", 700, 74, "state files", anchor="middle")

    s.legend(548, [
        ("cat", "network", "Networking"),
        ("cat", "database", "Database"),
        ("cat", "compute", "Compute"),
        ("cat", "storage", "Storage"),
        ("cat", "security", "Identity"),
        ("cat", "integration", "Budget"),
        ("line", True, "Terraform state"),
    ])
    s.save("step-09-environments.svg")


# ---------------------------------------------------------------------------
# Storybook frames (docs/storybook). Each set keeps every box in the same place
# in every frame, so the reader's eye only has to find what changed. Things
# that come later are faded, what is new has a gold ring, what failed is red.

FRAME_STYLE = """<style>
  .ghost { opacity:.28; }
  .ring { fill:none; stroke:#D69E2E; stroke-width:2.2; }
  .down { fill:rgba(221,52,76,.07); stroke:#DD344C; stroke-width:1.4; stroke-dasharray:6 4; }
  .dn { font-size:11px; font-weight:700; fill:#DD344C; }
  .ft { font-size:14px; font-weight:700; fill:#15202B; }
  .fs { font-size:11.5px; fill:#5A6877; }
  @media (prefers-color-scheme: dark) {
  .ft { fill:#E2E8EE; } .fs { fill:#95A3B1; }
  .ring { stroke:#F6C453; }
  }
</style>"""


class Frame(Svg):
    def __init__(self, w, h, label, title, sub):
        super().__init__(w, h, label)
        self.add(FRAME_STYLE)
        self.text("ft", 20, 30, title)
        self.text("fs", 20, 49, sub)

    def begin(self, cls):
        self.add(f'<g class="{cls}">')

    def end(self):
        self.add("</g>")

    def ring(self, x, y, w=170, h=44):
        self.add(f'<rect class="ring" x="{x-4}" y="{y-4}" width="{w+8}" height="{h+8}" rx="9"/>')

    def down_zone(self, x, y, w, h, label):
        self.add(f'<rect class="down" x="{x}" y="{y}" width="{w}" height="{h}" rx="8"/>')
        self.text("dn", x + w - 12, y + h - 10, label, anchor="end")

    def frame_legend(self, y, down=False):
        x = 20
        items = [("ring", "new or changed in this frame"), ("ghost", "comes later, or gone"),
                 ("line", "traffic or route")]
        if down:
            items.append(("down", "failed"))
        for kind, label in items:
            if kind == "ring":
                self.add(f'<rect class="ring" x="{x}" y="{y-11}" width="22" height="14" rx="4"/>')
            elif kind == "ghost":
                self.add(f'<rect class="n ghost" x="{x}" y="{y-11}" width="22" height="14" rx="3"/>')
            elif kind == "down":
                self.add(f'<rect class="down" x="{x}" y="{y-11}" width="22" height="14" rx="3"/>')
            else:
                self.add(f'<path class="ar" d="M{x},{y-4} h22"/>')
            x += 28
            self.add(f'<text class="lg" x="{x}" y="{y}">{label}</text>')
            x += 6.2 * len(label) + 26


def story_vpc_frames():
    """Episode 5: the VPC built up one piece at a time."""
    frames = [
        ("Frame 1 · A VPC and six subnets",
         "All six are the same so far. Their only route is 10.20.0.0/16 local: nothing gets in or out."),
        ("Frame 2 · The front door",
         "An internet gateway, and one route in the public route table: 0.0.0.0/0 to the gateway."),
        ("Frame 3 · The exit-only door",
         "A NAT gateway in public-1a. Both private route tables send 0.0.0.0/0 to it."),
        ("Frame 4 · A room with no door, and a private tunnel",
         "The isolated subnets get no route out. The private subnets get a free S3 gateway endpoint."),
        ("Frame 5 · Moving in",
         "The public subnets hold only the NAT gateway. Everything we run is private or isolated."),
    ]
    names = {"pub": "PUBLIC", "priv": "PRIVATE", "iso": "ISOLATED"}
    for n, (title, sub) in enumerate(frames, start=1):
        s = Frame(980, 600, f"Episode 5, {title}: {sub}", title, sub)
        s.card(405, 62, "client", "WWW", "Internet", "users, websites")
        s.rect("vpc", 30, 150, 778, 395)
        s.text("gl vpcl", 44, 170, "VPC · 10.20.0.0/16")

        bands = {}
        for z, (zx, az) in enumerate([(44, "1a"), (424, "1c")]):
            s.rect("grp", zx, 182, 370, 350)
            s.text("gt", zx + 12, 200, f"Availability Zone {az}")
            bx = zx + 10
            for kind, by, bh, cidr in [("pub", 210, 80, z), ("priv", 300, 120, 10 + z), ("iso", 430, 92, 20 + z)]:
                s.rect(kind, bx, by, 350, bh, rx=6)
                s.text(f"sl {kind}l", bx + 10, by + 16, f"{names[kind]}-{az} · 10.20.{cidr}.0/24")
                bands[(kind, az)] = (bx, by, bh)

        def note(kind, az, text):
            bx, by, bh = bands[(kind, az)]
            if kind in ("pub", "iso"):
                s.text("s", bx + 340, by + 16, text, anchor="end")
            else:
                s.text("s", bx + 10, by + bh - 10, text)

        def ring_band(kind):
            for az in ("1a", "1c"):
                bx, by, bh = bands[(kind, az)]
                s.ring(bx, by, 350, bh)

        for az in ("1a", "1c"):
            note("pub", az, "local only" if n == 1 else "0.0.0.0/0 to the gateway")
            note("priv", az, {1: "route: local only", 2: "route: local only",
                              3: "0.0.0.0/0 to the NAT gateway"}.get(n, "0.0.0.0/0 to NAT · S3 to the endpoint"))
            note("iso", az, "local only" if n < 4 else "no route out, ever")
        if n == 1:
            for kind in ("pub", "priv", "iso"):
                ring_band(kind)

        # internet gateway
        if n < 2:
            s.begin("ghost")
        s.card(405, 128, "network", "IGW", "Internet gateway", "free, both ways")
        if n < 2:
            s.end()
        else:
            s.arrow("M490,106 V128", both=True)
            s.arrow("M530,172 V190 H609 V210", both=True)
            if n == 2:
                s.arrow("M450,172 V190 H229 V210", both=True)
                s.ring(405, 128)
                ring_band("pub")

        # NAT gateway
        if n < 3:
            s.begin("ghost")
        s.card(226, 238, "network", "NAT", "NAT gateway", "Elastic IP · exit only")
        if n < 3:
            s.end()
        else:
            s.arrow("M396,252 H419 V190 H450 V172")
            s.arrow("M130,300 V260 H224")
            s.text("al", 136, 284, "0.0.0.0/0")
            s.arrow("M434,344 H408 V268 H398")
            if n == 3:
                s.ring(226, 238)

        # S3 endpoint and S3
        if n < 4:
            s.begin("ghost")
        s.card(614, 330, "network", "VPCE", "S3 endpoint", "gateway · free", w=160)
        s.card(822, 330, "storage", "S3", "Amazon S3", "in Tokyo", w=145)
        if n < 4:
            s.end()
        else:
            s.arrow("M774,352 H822")
            s.arrow("M404,423 H694 V376", thin=True)
            if n == 4:
                s.ring(614, 330, 160)
                ring_band("iso")

        if n == 5:
            for x, y, cat, ab, t, sb, w in [
                (64, 330, "network", "ALB", "Load balancer", "internal", 150),
                (222, 330, "compute", "ECS", "Tasks", "api, check, rollup", 160),
                (444, 330, "compute", "ECS", "Tasks", "api, check, rollup", 160),
                (64, 456, "database", "RDS", "RDS primary", "no public address", 180),
                (444, 456, "database", "RDS", "RDS standby", "prod only", 180),
            ]:
                s.card(x, y, cat, ab, t, sb, w=w)
                s.ring(x, y, w)

        s.frame_legend(580)
        s.save(f"story-05-vpc-{n}.svg")


def story_deploy_frames():
    """Episode 8: a rolling deploy with no downtime."""
    frames = [
        ("Frame 1 · Before", "Revision 6 serves every request.", "healthy · serving", "not started yet"),
        ("Frame 2 · Start the new one next to it",
         "ECS starts revision 7. The load balancer only health-checks it; users see nothing.",
         "healthy · serving", "starting: migrate, then api"),
        ("Frame 3 · Both serve",
         "Revision 7 passed two health checks in a row, so it gets requests too.",
         "healthy · serving", "healthy · serving"),
        ("Frame 4 · Drain the old one",
         "No new requests go to revision 6. It gets 30 seconds to finish, then stops.",
         "draining · 30 s, then stops", "healthy · serving"),
    ]
    for n, (title, sub, old_sub, new_sub) in enumerate(frames, start=1):
        s = Frame(780, 320, f"Episode 8, {title}: {sub}", title, sub)
        s.card(40, 160, "network", "ALB", "Load balancer", "internal · :80", w=180)
        s.rect("grp", 380, 80, 370, 200)
        s.text("gt", 392, 99, "ECS service uptime-dev-api")

        if n == 4:
            s.begin("ghost")
        s.card(430, 112, "compute", "ECS", "api task · revision 6", old_sub, w=280)
        if n == 4:
            s.end()
            s.ring(430, 112, 280)

        if n == 1:
            s.begin("ghost")
        s.card(430, 204, "compute", "ECS", "api task · revision 7", new_sub, w=280, dash=(n == 2))
        if n == 1:
            s.end()
        if n in (2, 3):
            s.ring(430, 204, 280)

        # load balancer to revision 6
        s.arrow("M220,176 H320 V134 H430", thin=(n == 4))
        s.text("al", 325, 126, "no new requests" if n == 4 else "requests")
        # load balancer to revision 7
        if n >= 2:
            s.arrow("M220,190 H320 V226 H430", thin=(n == 2))
            s.text("al", 325, 246, "health checks only" if n == 2 else "requests")

        s.frame_legend(305)
        s.save(f"story-08-deploy-{n}.svg")


def story_failover_frames():
    """Episode 7: RDS Multi-AZ failover."""
    frames = [
        ("Frame 1 · Normal",
         "The app connects to the endpoint name. Every write is copied to the standby before it's confirmed."),
        ("Frame 2 · Zone 1a fails",
         "The primary is gone, and every open connection breaks."),
        ("Frame 3 · One to two minutes later",
         "RDS promotes the standby and points the same name at it. The app reconnects and carries on."),
    ]
    for n, (title, sub) in enumerate(frames, start=1):
        s = Frame(780, 380, f"Episode 7, {title}: {sub}", title, sub)
        s.card(295, 72, "compute", "ECS", "api and job tasks", "connect by name", w=190)
        s.card(260, 150, "network", "DNS", "endpoint", "uptime-prod.xxxx.rds.amazonaws.com", w=260)
        s.arrow("M390,116 V150")
        s.rect("grp", 40, 225, 330, 120)
        s.text("gt", 52, 244, "Availability Zone 1a")
        s.rect("grp", 410, 225, 330, 120)
        s.text("gt", 422, 244, "Availability Zone 1c")

        if n == 3:
            s.begin("ghost")
        s.card(110, 270, "database", "RDS", "RDS primary", "unreachable" if n == 2 else "zone 1a", w=190)
        if n == 3:
            s.end()
        if n == 2:
            s.down_zone(40, 225, 330, 120, "zone 1a down")

        if n == 3:
            s.card(480, 270, "database", "RDS", "RDS primary", "promoted · zone 1c", w=190)
            s.ring(480, 270, 190)
        else:
            s.card(480, 270, "database", "RDS", "RDS standby", "zone 1c", w=190)

        if n == 1:
            s.arrow("M330,194 V212 H205 V270")
            s.arrow("M300,292 H480", thin=True)
            s.text("al", 390, 284, "every write copied", anchor="middle")
        elif n == 2:
            s.arrow("M330,194 V212 H205 V270", thin=True)
            s.text("al", 214, 206, "connections break")
        else:
            s.arrow("M450,194 V212 H575 V270")
            s.text("al", 584, 206, "same name, new address")

        s.frame_legend(366, down=(n == 2))
        s.save(f"story-07-failover-{n}.svg")


def story_zone_frames():
    """Episode 14: prod survives losing zone 1a."""
    frames = [
        ("Frame 1 · Normal",
         "An api task and a NAT gateway in each zone. The database primary in 1a copies every write to 1c."),
        ("Frame 2 · Zone 1a goes dark",
         "The api task, the NAT gateway and the database primary in 1a are gone. Open connections break."),
        ("Frame 3 · About two minutes later",
         "Requests go to 1c only, RDS has promoted the standby, ECS starts a second task, checks leave through NAT 1c."),
    ]
    for n, (title, sub) in enumerate(frames, start=1):
        s = Frame(980, 470, f"Episode 14, {title}: {sub}", title, sub)
        s.card(400, 66, "network", "ALB", "Load balancer", "spans both zones", w=180)
        s.rect("grp", 40, 140, 440, 280)
        s.text("gt", 468, 159, "Availability Zone 1a", anchor="end")
        s.rect("grp", 500, 140, 440, 280)
        s.text("gt", 928, 159, "Availability Zone 1c", anchor="end")

        if n == 3:
            s.begin("ghost")
        s.card(70, 175, "compute", "ECS", "api task", "zone 1a")
        s.card(70, 255, "network", "NAT", "NAT gateway", "zone 1a")
        s.card(70, 340, "database", "RDS", "RDS primary", "zone 1a", w=190)
        if n == 3:
            s.end()
        if n == 2:
            s.down_zone(40, 140, 440, 280, "zone 1a down")

        s.card(530, 175, "compute", "ECS", "api task", "zone 1c")
        s.card(530, 255, "network", "NAT", "NAT gateway", "zone 1c")
        s.card(730, 255, "compute", "ECS", "check task", "every minute", w=180, dash=True)
        if n == 3:
            s.card(530, 340, "database", "RDS", "RDS primary", "promoted", w=190)
            s.ring(530, 340, 190)
            s.card(730, 175, "compute", "ECS", "api task", "replacement, starting", w=180, dash=True)
            s.ring(730, 175, 180)
        else:
            s.card(530, 340, "database", "RDS", "RDS standby", "zone 1c", w=190)

        # load balancer to the tasks
        if n < 3:
            s.arrow("M455,110 V128 H155 V175", thin=(n == 2))
        s.arrow("M525,110 V128 H615 V175")
        if n == 2:
            s.text("al", 300, 122, "health checks fail", anchor="middle")
        # check task out through its zone's NAT
        s.arrow("M730,277 H700")
        s.text("al", 726, 249, "checks carry on" if n == 3 else "out to websites", anchor="end")
        if n == 1:
            s.arrow("M260,362 H530", thin=True)
            s.text("al", 395, 354, "every write copied", anchor="middle")

        s.frame_legend(452, down=(n == 2))
        s.save(f"story-14-zone-{n}.svg")


local_architecture()
aws_architecture()
aws_network()
step03_data()
step04_compute()
step05_edge()
step06_jobs()
step07_observability()
step08_cicd()
step09_environments()
story_vpc_frames()
story_deploy_frames()
story_failover_frames()
story_zone_frames()
print("done")
