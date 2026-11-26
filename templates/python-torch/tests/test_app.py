import pytest

from app import device


def test_device_is_known() -> None:
    assert device() in ("cuda", "cpu")


def test_matmul_on_device() -> None:
    # Skipped in `nix flake check`, where the `gpu` group (torch) isn't installed.
    torch = pytest.importorskip("torch")
    a = torch.ones(4, 4, device=device())
    assert (a @ a).sum().item() == 64
