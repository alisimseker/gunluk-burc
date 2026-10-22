"""Geriye dönük uyumluluk: tüm kütüphaneler artık library.py'de."""
import sys

from library import main

if __name__ == "__main__":
    sys.exit(main())
