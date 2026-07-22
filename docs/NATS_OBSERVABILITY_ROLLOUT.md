# NATS Observability Rollout Gate

Enabling the private Prometheus exporter changes the NATS Pod template and
therefore restarts the single-node StatefulSet. The restart must not replay
acknowledged JetStream history.

## Intentional replay exception

Normal product consumers use stable durable names, explicit acknowledgements,
persistent file storage, and `CreateOrUpdateConsumer`. They resume from their
stored acknowledgement floors after a Pod restart.

`discord-frolf-bot`'s `linkprompt.Bootstrap` is intentionally different. It
uses a temporary, identity-event-only `DeliverAll` consumer to rebuild an
in-memory link checker. Preserve that bootstrap until a materialized identity
projection replaces it; do not change consumer names, subjects, delivery
policies, or acknowledgement behavior as part of this rollout.

## Before Argo CD sync

1. Port-forward NATS monitoring locally and capture the complete snapshot:

   ```bash
   kubectl -n frolf-bot port-forward statefulset/frolf-nats 8222:8222
   curl --silent --show-error --fail \
     'http://127.0.0.1:8222/jsz?streams=true&consumers=true&config=true' \
     --output nats-jsz-before.json
   ```

2. Record every stream message count and every durable's name, delivered
   position, acknowledgement floor, pending count, and redelivery count.
3. Render the pinned chart and confirm these invariants:
   - StatefulSet: `frolf-nats`
   - service name: `frolf-nats-headless`
   - file-store mount: `frolf-nats-js` at `/data`
   - PVC: `frolf-nats-js-frolf-nats-0`
4. Review the Git diff. Block the rollout if it changes consumer names,
   filters, delivery policies, stream retention/storage, the NATS container,
   or volume claim templates.

## After the restart

Capture the same endpoint as `nats-jsz-after.json`, then compare by stream and
durable name:

- the same streams and durables exist;
- acknowledgement floors and delivered positions never move backward;
- redelivery counts do not show a backlog-wide jump;
- only messages that were pending or unacknowledged before the restart are
  newly delivered.

Finally confirm application publish/consume health and that
`nats_varz_*`, `nats_stream_*`, and `nats_consumer_*` metrics are present in
Mimir. Do not declare the rollout complete without the two retained snapshots.
