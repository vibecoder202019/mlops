#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
Custom Ansible Module — hello_python

Module Python tuỳ chỉnh chạy trên AWX task pod.
Đặt file này trong thư mục library/ của project AWX.

Cách dùng trong playbook:
  - name: Gọi custom module
    hello_python:
      name: "AWX"
    register: greeting

Ansible tự tìm module trong library/ (không cần đường dẫn đầy đủ).
"""

from __future__ import absolute_import, division, print_function

__metaclass__ = type

# Ansible module utils — import từ Ansible, có sẵn khi chạy trên AWX
from ansible.module_utils.basic import AnsibleModule


def run_module():
    # Định nghĩa argument module nhận từ playbook
    module_args = dict(
        name=dict(type="str", required=True, help="Tên cần chào"),
        uppercase=dict(type="bool", default=False, help="In hoa kết quả"),
    )

    # AnsibleModule — boilerplate bắt buộc cho mọi custom module
    module = AnsibleModule(argument_spec=module_args, supports_check_mode=True)

    name = module.params["name"]
    uppercase = module.params["uppercase"]

    message = f"Xin chào {name} từ custom Python module!"

    if uppercase:
        message = message.upper()

    # exit_json — trả kết quả về Ansible (hiện qua register)
    module.exit_json(changed=False, message=message, name=name)


def main():
    run_module()


if __name__ == "__main__":
    main()
