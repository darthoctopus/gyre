
if (trans_) then
B(1, 1) = alpha_omg*c_1*omega_c**2 + l_i + 1
B(2, 1) = (l_i + 1)/V_2
B(3, 1) = alpha_grv*(l_i + 1)
B(4, 1) = 0
B(1, 2) = alpha_omg*c_1*omega_c**2 + l_i + 1
B(2, 2) = (l_i + 1)/V_2
B(3, 2) = 0
B(4, 2) = -alpha_grv
else
B(1, 1) = alpha_omg*c_1*omega_c**2 + l_i + 1
B(2, 1) = alpha_omg*c_1*omega_c**2 + l_i + 1
B(1, 2) = (l_i + 1)/V_2
B(2, 2) = (l_i + 1)/V_2
B(1, 3) = alpha_grv*(l_i + 1)
B(2, 3) = 0
B(1, 4) = 0
B(2, 4) = -alpha_grv
endif
if (PRESENT(s)) then
s(1) = -c_1*y_T_1*(l_i + 1)
s(2) = 0
endif
