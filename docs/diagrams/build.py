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
    s = Svg(1320, 740, "Target AWS architecture: users reach CloudFront with WAF, which serves web files from S3 and "
                       "forwards /api to a load balancer in public subnets. ECS Fargate tasks in private subnets "
                       "use RDS MySQL in isolated subnets and reach the internet through a NAT gateway.")

    s.text("sl", 20, 116, "INTERNET")
    s.text("sl", 160, 116, "EDGE · GLOBAL")
    s.rect("region", 340, 40, 965, 660, rx=10)
    s.text("gl reg", 355, 60, "AWS Region")
    s.rect("vpc", 355, 70, 660, 610)
    s.text("gl vpcl", 369, 89, "VPC 10.0.0.0/16 · 2 Availability Zones")
    s.rect("pub", 370, 98, 190, 570, rx=6)
    s.text("sl publ", 382, 116, "PUBLIC SUBNETS")
    s.rect("priv", 575, 98, 240, 570, rx=6)
    s.text("sl privl", 587, 116, "PRIVATE APP SUBNETS")
    s.rect("iso", 830, 98, 170, 570, rx=6)
    s.text("sl isol", 842, 116, "ISOLATED DATA")
    s.text("sl", 1060, 116, "REGIONAL SERVICES")

    s.rect("grp", 585, 130, 220, 520)
    s.text("gt", 597, 149, "ECS cluster · Fargate")

    # internet + edge
    s.card(20, 300, "client", "WWW", "Users", "browser", w=110)
    s.card(20, 520, "network", "NET", "Websites", "example.com", w=110)
    s.card(160, 160, "network", "R53", "Route 53", "DNS for our domain", w=160)
    s.card(160, 300, "network", "CF", "CloudFront", "HTTPS · CDN", w=160)
    s.card(160, 380, "security", "WAF", "WAF", "rules on CloudFront", w=160)
    s.card(160, 460, "security", "ACM", "ACM", "TLS certificates", w=160)

    # vpc
    s.card(380, 300, "network", "ALB", "Load balancer", "ALB · HTTPS 443")
    s.card(380, 520, "network", "NAT", "NAT gateway", "outbound only")
    s.card(600, 200, "compute", "ECS", "migrate task", "before each deploy", dash=True)
    s.card(600, 300, "compute", "ECS", "api service", "2+ tasks · :8080")
    s.card(600, 400, "compute", "ECS", "check task", "every minute", dash=True)
    s.card(600, 460, "compute", "ECS", "rollup task", "every night", dash=True)
    s.card(835, 300, "database", "RDS", "RDS MySQL", "Multi-AZ · standby", w=160)

    # regional
    s.card(1060, 160, "storage", "S3", "S3 · web", "React build files")
    s.card(1060, 200 + 30, "compute", "ECR", "ECR", "container images")
    s.card(1060, 300, "security", "SM", "Secrets Manager", "database password")
    s.card(1060, 400, "integration", "EB", "EventBridge", "Scheduler")
    s.card(1060, 520, "storage", "S3", "S3 · reports", "daily CSV files")
    s.card(1060, 600, "integration", "CW", "CloudWatch", "logs, metrics, alarms")

    # arrows
    s.arrow("M75,300 V182 H160", thin=True)
    s.text("al", 80, 240, "DNS lookup")
    s.arrow("M130,322 H160")
    s.arrow("M320,310 H332 V22 H1145 V160")
    s.text("al", 740, 16, "/  web files", anchor="middle")
    s.arrow("M320,332 H380")
    s.text("al", 350, 350, "/api/*", anchor="middle")
    s.arrow("M550,322 H600")
    s.text("al", 575, 314, ":8080", anchor="middle")
    s.arrow("M770,322 H835")
    s.text("al", 802, 314, "3306", anchor="middle")
    s.arrow("M770,412 H915 V344")
    s.arrow("M770,478 H915 V412")
    s.text("al", 925, 388, "save and read results")
    s.arrow("M1060,422 H770")
    s.text("al", 1000, 414, "starts on schedule", anchor="middle")
    s.arrow("M1060,436 H1040 V482 H770", thin=True)
    s.arrow("M770,494 H1020 V542 H1060")
    s.text("al", 1040, 558, "CSV", anchor="middle")
    s.arrow("M600,430 H566 V542 H550")
    s.text("al", 540, 510, "internet calls", anchor="end")
    s.arrow("M380,542 H130")
    s.text("al", 255, 534, "through the internet gateway", anchor="middle")
    s.arrow("M805,222 H1060 V252", thin=True)
    s.text("al", 930, 214, "pull image, read secret, send logs", anchor="middle")

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

local_architecture()
aws_architecture()
aws_network()
print("done")
