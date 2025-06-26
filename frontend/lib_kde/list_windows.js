function intersect(r1, r2) {
    let x1 = Math.max(r1.x, r2.x);
    let y1 = Math.max(r1.y, r2.y);
    let x2 = Math.min(r1.x + r1.width, r2.x + r2.width);
    let y2 = Math.min(r1.y + r1.height, r2.y + r2.height);
    if (x2 > x1 && y2 > y1) {
        return { x: x1, y: y1, width: x2 - x1, height: y2 - y1 };
    }
    return null;
}

function subtractRect(rect, hole) {
    const parts = [];

    const rx1 = rect.x;
    const ry1 = rect.y;
    const rx2 = rect.x + rect.width;
    const ry2 = rect.y + rect.height;

    const hx1 = hole.x;
    const hy1 = hole.y;
    const hx2 = hole.x + hole.width;
    const hy2 = hole.y + hole.height;

    
    if (hy1 > ry1 && hy1 < ry2) {
        parts.push({
            x: rx1,
            y: ry1,
            width: rect.width,
            height: hy1 - ry1
        });
    }

    
    if (hy2 < ry2 && hy2 > ry1) {
        parts.push({
            x: rx1,
            y: hy2,
            width: rect.width,
            height: ry2 - hy2
        });
    }

    
    const topY = Math.max(ry1, hy1);
    const bottomY = Math.min(ry2, hy2);
    if (hx1 > rx1 && hx1 < rx2) {
        parts.push({
            x: rx1,
            y: topY,
            width: hx1 - rx1,
            height: bottomY - topY
        });
    }

    
    if (hx2 < rx2 && hx2 > rx1) {
        parts.push({
            x: hx2,
            y: topY,
            width: rx2 - hx2,
            height: bottomY - topY
        });
    }

    return parts;
}

function getVisibleParts(target, others) {
    let visibleRects = [{
        x: target.x,
        y: target.y,
        width: target.width,
        height: target.height
    }];

    for (let i = 0; i < others.length; i++) {
        const o = others[i];
        if (o === target || o.caption === "" || o.stackingOrder < target.stackingOrder || o.caption === "Overlay" || !o.normalWindow)
            continue;

        const oRect = {
            x: o.x,
            y: o.y,
            width: o.width,
            height: o.height
        };

        let newRects = [];

        for (let j = 0; j < visibleRects.length; j++) {
            const part = visibleRects[j];
            const overlap = intersect(part, oRect);
            if (overlap) {
                const sub = subtractRect(part, overlap);
                newRects = newRects.concat(sub);
            } else {
                newRects.push(part);
            }
        }

        visibleRects = newRects;
        if (visibleRects.length === 0)
            break;
    }

    return visibleRects;
}

const clients = workspace.windowList();

for (let i = 0; i < clients.length; i++) {
    const c = clients[i];
    if (c.caption === "")
        continue;

    const visibleParts = getVisibleParts(c, clients);
    for (let j = 0; j < visibleParts.length; j++) {
      const r = visibleParts[j];
      if (r.width <= 0 || r.height <= 0 || c.caption === "Overlay" || c.caption === "hell - Wine Desktop" || !c.normalWindow)
        continue;
        print(
            Math.round(r.x) + " " +
            Math.round(r.y) + " " +
            Math.round(r.width) + " " +
            Math.round(r.height) + " " +
            (c.active ? "1" : "0") + " " +
            encodeURIComponent(c.internalId)
        );
    }
}
